NAME := NH-Signer
SCHEME := Feather
PLATFORMS := iphoneos

TMP := $(TMPDIR)/$(NAME)
CERT_JSON_URL := https://backloop.dev/pack.json

.PHONY: all clean deps $(PLATFORMS)

all: $(PLATFORMS)

clean:
	rm -rf $(TMP)
	rm -rf packages
	rm -rf Payload
	rm -rf build

deps:
	mkdir -p deps
	if [ ! -f deps/server.crt ]; then \
		curl -fsSL "$(CERT_JSON_URL)" -o cert.json && \
		jq -r '.cert' cert.json > deps/server.crt && \
		jq -r '.key1, .key2' cert.json > deps/server.pem && \
		jq -r '.info.domains.commonName' cert.json > deps/commonName.txt || true; \
	fi

$(PLATFORMS): deps
	rm -rf packages Payload build
	DEST="generic/platform=iOS"; \
	xcodebuild \
		-workspace Feather.xcworkspace \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination "$$DEST" \
		-archivePath build/$(NAME).xcarchive \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGN_IDENTITY="" \
		ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO \
		STRIP_INSTALLED_PRODUCT=YES \
		COPY_PHASE_STRIP=YES \
		STRIPFLAGS="-rSTx" \
		DEPLOYMENT_POSTPROCESSING=YES \
		DEAD_CODE_STRIPPING=YES \
		SWIFT_OPTIMIZATION_LEVEL="-Osize" \
		COMPRESS_PNG_FILES=YES \
		SWIFT_STRICT_CONCURRENCY=minimal \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
		archive

	mkdir -p Payload
	cp -R build/$(NAME).xcarchive/Products/Applications/*.app Payload/$(NAME).app
	chmod -R 0755 Payload/$(NAME).app

	# Strip symbols to significantly reduce IPA size
	find Payload/$(NAME).app -name "*.dylib" -exec strip -S {} + 2>/dev/null || true
	find Payload/$(NAME).app/Frameworks -type f -exec strip -S {} + 2>/dev/null || true
	strip -rSTx "Payload/$(NAME).app/$(SCHEME)" 2>/dev/null || strip -S "Payload/$(NAME).app/$(SCHEME)" 2>/dev/null || true
	rm -rf Payload/$(NAME).app/*.dSYM Payload/$(NAME).app/_CodeSignature 2>/dev/null || true

	codesign --force --sign - --timestamp=none Payload/$(NAME).app || true
	cp deps/* Payload/$(NAME).app/ || true

	mkdir -p packages
	# Maximum zip compression level 9
	cd Payload && zip -9 -r -y "../packages/$(NAME).ipa" "$(NAME).app" && cd ..
