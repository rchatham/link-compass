import SwiftUI

@main
struct LinkCompassApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("LinkCompass") {
            OnboardingView()
        }
        .windowResizability(.contentSize)

        Settings {
            PreferencesView()
        }
    }
}
