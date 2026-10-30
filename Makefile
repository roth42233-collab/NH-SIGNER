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

deps:
	rm -rf deps || true
	mkdir -p deps

	curl -fsSL "$(CERT_JSON_URL)" -o cert.json
	jq -r '.cert' cert.json > deps/server.crt
	jq -r '.key1, .key2' cert.json > deps/server.pem
	jq -r '.info.domains.commonName' cert.json > deps/commonName.txt


$(PLATFORMS): deps
	rm -rf _build

	DEST="generic/platform=iOS"; \
	xcodebuild \
		-project Feather.xcodeproj \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination "$$DEST" \
		-derivedDataPath $(TMP)/$@ \
		-skipPackagePluginValidation \
		CODE_SIGNING_ALLOWED=NO \
		ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES=NO

	mkdir -p _build/Payload
	cp -R _build/Applications/*.app _build/Payload/NH-Signer.app
	chmod -R 0755 _build/Payload/NH-Signer.app
	codesign --force --sign - --timestamp=none _build/Payload/NH-Signer.app
	cp deps/* _build/Payload/NH-Signer.app/ || true

	mkdir -p packages
	ditto -c -k --sequesterRsrc --keepParent _build/Payload "packages/NH-Signer.ipa"

