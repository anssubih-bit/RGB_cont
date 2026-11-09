# Strip Control for iPhone (SwiftUI)

Native app for the LEDBLE / ELK-BLEDOM controller (the one that uses LotusLanternX).

## Build and install (needs a Mac with Xcode 15 or newer; the app targets iOS 17+)

1. In Xcode: File > New > Project > iOS > App. Name it `StripControl`, Interface: SwiftUI, Language: Swift.
2. Delete the generated `ContentView.swift` and `StripControlApp.swift`, then drag the four files from the
   `StripControl/` folder into the project (tick "Copy items if needed").
3. Select the project > target StripControl > Info tab, add the key
   **Privacy - Bluetooth Always Usage Description** (`NSBluetoothAlwaysUsageDescription`)
   with a value like "Used to control your LED strip".
4. Signing & Capabilities: choose your Apple ID as the Team (a free account works).
5. Plug in your iPhone, pick it as the run destination, press Run.
   On the phone: Settings > General > VPN & Device Management > trust your developer certificate.
   On iOS 16+, also turn on Settings > Privacy & Security > Developer Mode.

With a free Apple ID the app expires after 7 days; just press Run again to reinstall.

Close LotusLanternX first: the controller only accepts one Bluetooth connection at a time.
