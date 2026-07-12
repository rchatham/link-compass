import SwiftUI

@main
struct LinkCompassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("LC") {
            MenuBarView()
        }
    }
}
