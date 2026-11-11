//
//  IPAIconExtractor.swift
//  Feather
//
//  Created by NAK VIP on 11.11.2026.
//

import Foundation
import UIKit
import zlib

private func decompressRawDeflate(data: Data, uncompressedSize: Int) -> Data? {
	guard uncompressedSize > 0, !data.isEmpty else { return nil }
	var stream = z_stream()
	// -MAX_WBITS (-15) tells zlib that data is raw deflate (RFC 1951) without zlib header
	let status = inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
	guard status == Z_OK else { return nil }
	defer { inflateEnd(&stream) }
	
	var outputData = Data(count: uncompressedSize)
	let decompressed: Data? = data.withUnsafeBytes { (inputBuffer: UnsafeRawBufferPointer) -> Data? in
		guard let inputPtr = inputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return nil }
		return outputData.withUnsafeMutableBytes { (outputBuffer: UnsafeMutableRawBufferPointer) -> Data? in
			guard let outputPtr = outputBuffer.baseAddress?.assumingMemoryBound(to: Bytef.self) else { return nil }
			stream.next_in = UnsafeMutablePointer(mutating: inputPtr)
			stream.avail_in = uInt(data.count)
			stream.next_out = outputPtr
			stream.avail_out = uInt(uncompressedSize)
			
			let res = inflate(&stream, Z_FINISH)
			if res == Z_STREAM_END || res == Z_OK {
				let bytesWritten = uncompressedSize - Int(stream.avail_out)
				return outputData.prefix(bytesWritten)
			}
			return nil
		}
	}
	return decompressed
}

final class IPAIconExtractor: @unchecked Sendable {
	static let shared = IPAIconExtractor()
	private init() {
		try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
	}

	private let memoryCache = NSCache<NSURL, UIImage>()
	
	private var diskCacheURL: URL {
		let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
			?? FileManager.default.temporaryDirectory
		return caches.appendingPathComponent("IPA_Icons", isDirectory: true)
	}
	
	private func cacheKey(for url: URL) -> String {
		let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
		let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
		let mtime = (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
		let raw = "\(url.lastPathComponent)_\(size)_\(Int(mtime))"
		return raw.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "\(raw.hashValue)"
	}
	
	func cachedImage(for url: URL) -> UIImage? {
		if let mem = memoryCache.object(forKey: url as NSURL) {
			return mem
		}
		let diskFile = diskCacheURL.appendingPathComponent("\(cacheKey(for: url)).png")
		if let image = UIImage(contentsOfFile: diskFile.path) {
			memoryCache.setObject(image, forKey: url as NSURL)
			return image
		}
		return nil
	}

	func extractIcon(from url: URL) async -> UIImage? {
		if let cached = cachedImage(for: url) {
			return cached
		}
		
		return await Task.detached(priority: .userInitiated) { [weak self] () -> UIImage? in
			guard let self = self else { return nil }
			guard let image = self._extractFromZip(url: url) else { return nil }
			
			// Save to memory
			self.memoryCache.setObject(image, forKey: url as NSURL)
			
			// Save to disk cache
			let diskFile = self.diskCacheURL.appendingPathComponent("\(self.cacheKey(for: url)).png")
			if let pngData = image.pngData() {
				try? pngData.write(to: diskFile, options: .atomic)
			}
			return image
		}.value
	}

	private struct ZipEntry {
		let name: String
		let method: UInt16
		let compressedSize: UInt32
		let uncompressedSize: UInt32
		let localOffset: UInt32
	}

	private func _extractFromZip(url: URL) -> UIImage? {
		guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
		defer { try? handle.close() }
		
		let fileSize: UInt64
		do {
			fileSize = try handle.seekToEnd()
		} catch {
			return nil
		}
		guard fileSize > 22 else { return nil }
		
		// Read tail to find EOCD (End of Central Directory: 0x06054b50)
		let readLength = min(fileSize, 65536)
		let readOffset = fileSize - readLength
		guard (try? handle.seek(toOffset: readOffset)) != nil else { return nil }
		guard let tailData = try? handle.read(upToCount: Int(readLength)) else { return nil }
		
		let eocdSignature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
		guard let eocdIndex = tailData.range(of: Data(eocdSignature), options: .backwards)?.lowerBound else {
			return nil
		}
		
		guard eocdIndex + 22 <= tailData.count else { return nil }
		let eocdBytes = tailData.subdata(in: eocdIndex..<eocdIndex + 22)
		
		let cdSize = eocdBytes.withUnsafeBytes { $0.load(fromByteOffset: 12, as: UInt32.self) }
		let cdOffset = eocdBytes.withUnsafeBytes { $0.load(fromByteOffset: 16, as: UInt32.self) }
		
		guard (try? handle.seek(toOffset: UInt64(cdOffset))) != nil else { return nil }
		guard let cdData = try? handle.read(upToCount: Int(cdSize)) else { return nil }
		
		var entries: [ZipEntry] = []
		var pos = 0
		while pos + 46 <= cdData.count {
			if cdData[pos] != 0x50 || cdData[pos + 1] != 0x4b || cdData[pos + 2] != 0x01 || cdData[pos + 3] != 0x02 {
				break
			}
			
			let method = cdData.withUnsafeBytes { $0.load(fromByteOffset: pos + 10, as: UInt16.self) }
			let cSize = cdData.withUnsafeBytes { $0.load(fromByteOffset: pos + 20, as: UInt32.self) }
			let uSize = cdData.withUnsafeBytes { $0.load(fromByteOffset: pos + 24, as: UInt32.self) }
			let nameLen = Int(cdData.withUnsafeBytes { $0.load(fromByteOffset: pos + 28, as: UInt16.self) })
			let extraLen = Int(cdData.withUnsafeBytes { $0.load(fromByteOffset: pos + 30, as: UInt16.self) })
			let commLen = Int(cdData.withUnsafeBytes { $0.load(fromByteOffset: pos + 32, as: UInt16.self) })
			let localOffset = cdData.withUnsafeBytes { $0.load(fromByteOffset: pos + 42, as: UInt32.self) }
			
			let nameStart = pos + 46
			if nameStart + nameLen <= cdData.count {
				let nameData = cdData.subdata(in: nameStart..<nameStart + nameLen)
				if let name = String(data: nameData, encoding: .utf8) {
					entries.append(ZipEntry(name: name, method: method, compressedSize: cSize, uncompressedSize: uSize, localOffset: localOffset))
				}
			}
			pos += 46 + nameLen + extraLen + commLen
		}
		
		// Score icon candidates
		func score(for entry: ZipEntry) -> Int {
			let lower = entry.name.lowercased()
			guard lower.hasPrefix("payload/") && lower.contains(".app/") else { return -1 }
			guard lower.hasSuffix(".png") else { return -1 }
			guard !lower.contains("/._") && !lower.contains("__macosx") else { return -1 }
			guard !lower.contains("/frameworks/") && !lower.contains("/plugins/") && !lower.contains(".bundle/") else { return -1 }
			
			if lower.contains("appicon60x60@2x") { return 100 }
			if lower.contains("appicon60x60@3x") { return 95 }
			if lower.contains("appicon76x76@2x~ipad") { return 90 }
			if lower.contains("appicon76x76@2x") { return 85 }
			if lower.contains("appicon") { return 80 }
			if lower.contains("icon@3x") { return 75 }
			if lower.contains("icon@2x") { return 70 }
			if lower.contains("icon.png") { return 65 }
			if lower.contains("icon") { return 60 }
			return 30
		}
		
		var bestEntry: ZipEntry? = nil
		var bestScore = -1
		
		for e in entries {
			let s = score(for: e)
			if s > bestScore {
				bestScore = s
				bestEntry = e
			}
		}
		
		guard let entry = bestEntry, bestScore > 0 else { return nil }
		
		// Read local file header (30 bytes)
		guard (try? handle.seek(toOffset: UInt64(entry.localOffset))) != nil else { return nil }
		guard let localHeader = try? handle.read(upToCount: 30), localHeader.count == 30 else { return nil }
		guard localHeader[0] == 0x50 && localHeader[1] == 0x4b && localHeader[2] == 0x03 && localHeader[3] == 0x04 else { return nil }
		
		let localNameLen = Int(localHeader.withUnsafeBytes { $0.load(fromByteOffset: 26, as: UInt16.self) })
		let localExtraLen = Int(localHeader.withUnsafeBytes { $0.load(fromByteOffset: 28, as: UInt16.self) })
		let dataOffset = UInt64(entry.localOffset) + 30 + UInt64(localNameLen + localExtraLen)
		
		guard (try? handle.seek(toOffset: dataOffset)) != nil else { return nil }
		guard let compressedData = try? handle.read(upToCount: Int(entry.compressedSize)) else { return nil }
		
		let rawData: Data
		if entry.method == 0 {
			rawData = compressedData
		} else if entry.method == 8 {
			guard let decomp = decompressRawDeflate(data: compressedData, uncompressedSize: Int(entry.uncompressedSize)) else {
				return nil
			}
			rawData = decomp
		} else {
			return nil
		}
		
		return UIImage(data: rawData)
	}
}
