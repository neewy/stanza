import SwiftUI
import SwiftData

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
    }
}

@main
struct StanzaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var modelContainer: ModelContainer
    @AppStorage("isOnboardingComplete") var isOnboardingComplete: Bool = false
    
    init() {
        do {
            modelContainer = try ModelContainer(for: TimeEntry.self, Category.self)
        } catch {
            fatalError("Failed to initialize SwiftData container.")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if !isOnboardingComplete {
                OnboardingWizardView(isOnboardingComplete: $isOnboardingComplete)
                    .frame(width: 500, height: 450)
            } else {
                MainWindow()
                    .modelContainer(modelContainer)
            }
        }
        .windowResizability(.contentSize)
        
        MenuBarExtra("Stanza", systemImage: "timer") {
            if isOnboardingComplete {
                MenuBarTrackerView()
                    .modelContainer(modelContainer)
            } else {
                Text("Please complete setup in the main window.")
                    .padding()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

struct MainWindow: View {
    var body: some View {
        TabView {
            MainWindowDashboard()
                .tabItem {
                    Label("Timer", systemImage: "clock")
                }
            
            PomodoroView()
                .tabItem {
                    Label("Pomodoro", systemImage: "timer")
                }
            
            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.xaxis")
                }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}
