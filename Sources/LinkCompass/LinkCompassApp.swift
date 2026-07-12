import SwiftUI

@main
struct LinkCompassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("LC", systemImage: "location.north.circle.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)

        Settings {
            PreferencesView()
        }
    }
}
