# LumiFur App Store Submission Checklist

Use this checklist before TestFlight or App Store review. Items marked "Owner" require a human decision or App Store Connect entry.

## Build Package

- Archive from `LumiFur.xcodeproj`; `LumiFur 2.xcodeproj` appears to be a stale duplicate and should not be used for App Store upload unless it is brought back in sync.
- Confirm `PrivacyInfo.xcprivacy` is included in the iOS app, widget extension, and watch app bundles.
- Generate Xcode's privacy report and compare it with the App Privacy answers before upload.
- Archive a Release build on the intended Xcode version and verify signing for the app, widget, and watch app.
- Run a device smoke test with the LumiFur controller powered on and with the controller unavailable.
- Run a watch smoke test for wrist flick controls and confirm the motion permission prompt is clear.
- Run OTA update tests for successful update, failed download, failed checksum, aborted upload, and retry after reconnect.

## App Store Connect Metadata

- Owner: App name
- Owner: Subtitle
- Owner: Description
- Owner: Keywords
- Owner: Support URL
- Owner: Privacy Policy URL
- Owner: Category and age rating
- Owner: Copyright
- Owner: Screenshots for every supported device size
- Owner: App preview videos, if used
- Owner: Export compliance and encryption answers
- Owner: Content rights answers

## Privacy Answers

- Tracking: No, unless a future SDK or backend starts using data for tracking.
- Data collection: disclose only data transmitted off device or made available to Richies 3D Ltd or a service provider.
- Bluetooth identifiers and controller telemetry currently appear to stay on device unless the user sends support material.
- Apple diagnostics/crash reports may be received according to the user's Apple settings.
- Third-party SDK manifests still need confirmation from the archived privacy report.

## Reviewer Notes Template

LumiFur controls compatible LumiFur Bluetooth LED controller hardware. Review can open the app without hardware; connection-dependent controls should show disconnected or unavailable states. To test the main hardware path, power on a LumiFur controller, grant Bluetooth permission, connect from the device list, change the active face/view, and confirm the controller updates.

Firmware update testing requires compatible controller hardware. Keep the controller powered and near the iPhone during upload. If an upload fails, reconnect over Bluetooth and retry the same firmware file; if the controller is unresponsive, power-cycle it once before retrying.

The watch app controls the paired iPhone app through WatchConnectivity. Wrist flick controls use Apple Watch motion data only when enabled by the user.

No account, demo credentials, in-app purchases, subscriptions, ads, or external payment links are used.
