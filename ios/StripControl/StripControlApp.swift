import SwiftUI

@main
struct StripControlApp: App {
    @StateObject private var strip = StripController()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(strip).preferredColorScheme(.dark) }
    }
}
