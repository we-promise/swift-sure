# FinanceKit device testing

## Build and install

Generate the project, open `Sure.xcodeproj`, select the **Sure** scheme and your
physical iPhone, and select your development team for Sure, Sure Watch, and the
FinanceKit background extension. Run from Xcode. Do not commit the generated
project or local signing settings.

```sh
xcodegen generate --spec Project.json
xcodebuild -project Sure.xcodeproj -scheme Sure -configuration Debug \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/Sure-device \
  DEVELOPMENT_TEAM='<your-team-id>' -allowProvisioningUpdates build
```

The FinanceKit capability is assigned to both the app and extension App IDs. Each
provisioning profile must carry its target's FinanceKit entitlement; the app and
extension also need their shared App Group and Keychain groups. A successful
unsigned build alone does not validate provisioning or signing. Xcode can refresh
stale profiles when the capabilities are enabled for the App IDs. Check
`NSFinancialDataUsageDescription` in the generated app plist as well.

Use an eligible iPhone on iOS 18 or later with authorized Wallet accounts. The
app checks FinanceKit availability at runtime. Local Wallet preview remains free;
remote sync additionally requires a verified subscription, an authenticated Sure
connection, preview access on the test server, and explicit family-data consent.
Use a disposable test family with the protocol-2 backend described in
[the contract baseline](SureContractBaseline.md); the pinned main revision alone
does not include these experimental endpoints.

## Device checks

1. On a fresh install, verify that local Wallet preview works without a Sure
   subscription or login. No financial records should upload.
2. Connect to the test server with an active subscription. Grant Wallet access
   and consent to family sharing. Start enrollment; the button should become
   accessible progress and repeated taps must not create extra connections.
3. Tap **Sync now**. Verify that Sure receives the selected accounts and source
   records. Check the separate accepted and imported timestamps against Sure.
4. Relaunch the app. It should recover the existing publisher and health rather
   than offer duplicate enrollment. Foreground activation should sync after
   entitlement refresh, with a one-minute debounce.
5. Exercise a server repair-required response and a local invalid-history-token
   outcome. Both must show **Repair required** until successful repair.
6. Interrupt connectivity during mapping, activation, upload, and receipt
   polling. Failed enrollment should attempt remote cleanup; accepted captures
   should remain pending until imported, without advancing the checkpoint early.
7. Log out while online and offline. Local publisher credentials, checkpoints,
   and pending captures must clear; no subsequent receipt request may use the
   old credential. Reopen the app and explicitly reconnect Wallet to access the
   free local preview again.
8. Let entitlement access lapse, then restore it. Downloaded records remain;
   connectivity suspends and resumes according to the verified entitlement.
9. With signing and provisioning configured for both App IDs, test background
   delivery on a physical iOS 26 device. Verify that recognized callbacks
   trigger the existing sync path and that an unknown-only callback does not
   start a full-history collection.

Simulator tests do not establish signing, provisioning, signed archives, or
physical-device delivery. Those checks require actual Wallet and server
interaction and are not claimed by simulator tests. Unattended sync remains
unverified until the prerequisites are met.

## Generated configuration checks

CI generates the Xcode project, builds the extension target unsigned for the
iOS Simulator, and checks the generated extension bundle identifier, release
version, and extension point. It also compares the App Group and Keychain group
declarations for the app and extension. These checks validate generated
configuration, not Apple entitlement approval or signing.

The app and extension entitlement inputs are
`App/iOS.entitlements` and
`FinanceKitBackground/FinanceKitBackground.entitlements`. Keep their shared
App Group and Keychain access group aligned with `Project.json` and the generated
extension configuration.

Background delivery must not be described as active without successful
provisioning, signing, and physical-device checks. A simulator build or unit test
is not evidence of unattended or locked-device delivery.

<!-- Parent: FinanceKitSyncArchitecture.md -->
