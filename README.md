# NH-Signer iOS 🚀

A lightweight, high-performance, native SwiftUI IPA sideloading and signing application for iOS.

## Features
- **Zero Third-Party SPM Bloat**: Completely native Pure Swift with no fragile external dependencies.
- **Certificate Manager**: Import and store `.p12` certificates and `.mobileprovision` profiles securely.
- **App Customization**: Modify Display Name, Bundle ID, and Version numbers before signing.
- **Built-in Local OTA Server**: Directly install signed IPAs onto your iOS device using `itms-services://` loopback.
- **Library Manager**: Keep track of signed applications, re-install, or export to Files / Share Sheet.

## Automated Builds
Every push to `main` automatically builds an unsigned / distribution-ready `.ipa` file using GitHub Actions and publishes it to GitHub Releases.
