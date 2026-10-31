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
		SWIFT_STRICT_CONCURRENCY=minimal \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=NO \
		archive

	mkdir -p Payload
	cp -R build/$(NAME).xcarchive/Products/Applications/*.app Payload/$(NAME).app
	chmod -R 0755 Payload/$(NAME).app
	codesign --force --sign - --timestamp=none Payload/$(NAME).app || true
	cp deps/* Payload/$(NAME).app/ || true

	mkdir -p packages
	ditto -c -k --sequesterRsrc --keepParent Payload "packages/$(NAME).ipa"
