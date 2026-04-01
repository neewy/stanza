import SwiftUI

struct OnboardingWizardView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var selectedTab = 0
    
    // Step 1: AW
    @State private var awRunning = false
    @State private var isInstallingAW = false
    @State private var awError: String?
    @State private var awInstallLog: String = ""
    @State private var isInstallingVSCode = false
    @State private var vscodeInstallLog: String = ""
    @State private var awConfigWritten = false
    
    // Step 2: Calendar
    @State private var calendarAuthorized = false
    
    // Step 3: Ollama
    @State private var ollamaRunning = false
    @State private var isInstallingOllama = false
    @State private var ollamaInstallLog: String = ""
    @State private var availableModels: [String] = []
    @State private var selectedModel: String = ""
    @State private var newModelToPull: String = "llama3.2:3b"
    @State private var isPulling = false
    
    var body: some View {
        ScrollView {
            VStack {
                if selectedTab == 0 {
                // STEP 0: Introduction
                VStack(spacing: 20) {
                    Image(systemName: "timer")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    Text("Welcome to Tracker").font(.largeTitle).bold()
                    Text("Your intelligent, completely open-source, offline-first time tracking assistant.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .top) {
                            Image(systemName: "shield.checkered").foregroundColor(.purple)
                            Text("**ActivityWatch:** An open-source tool that transparently logs your active windows locally. You own 100% of your data.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(alignment: .top) {
                            Image(systemName: "calendar").foregroundColor(.red)
                            Text("**Apple Calendar:** Provides contextual awareness of your meetings.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(alignment: .top) {
                            Image(systemName: "brain").foregroundColor(.orange)
                            Text("**Ollama AI:** Summarizes all this noise into simple human-readable tasks.")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    Spacer()
                    Button("Get Started") { selectedTab = 1 }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                .padding(.vertical)
            } else if selectedTab == 1 {
                // STEP 1: AW
                VStack(spacing: 20) {
                    Image(systemName: "eyes")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    Text("ActivityWatch Integration").font(.title).bold()
                    Text("ActivityWatch runs locally to track your active windows, creating completely private suggestions.")
                        .multilineTextAlignment(.center).padding(.horizontal)
                    
                    if awRunning {
                        Text("✅ ActivityWatch is running!")
                            .foregroundColor(.green)
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            Text("1. Enable Accessibility & Input Monitoring in System Settings")
                            Button("Open Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
                                    NSWorkspace.shared.open(url)
                                }
                            }.buttonStyle(.bordered).controlSize(.small)
                            
                            Text("2. Enable Deep Keyboard/Mouse metrics")
                            Button(awConfigWritten ? "✅ Configured (Restart AW to apply)" : "Write aw-qt.toml config") {
                                enforceAWInputConfig()
                                awConfigWritten = true
                            }.buttonStyle(.bordered).controlSize(.small).disabled(awConfigWritten)
                        }
                        .font(.caption)
                        .padding(.vertical, 8)
                        
                        Divider()
                        Text("3. Install Tracking Plugins").font(.subheadline).bold()
                        
                        HStack(spacing: 15) {
                            Button("Web Browsers") {
                                if let url = URL(string: "https://docs.activitywatch.net/en/latest/watchers.html#aw-watcher-web") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("Editors (VSCode/Cursor) 1-Click") { installVSCodeAW() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(isInstallingVSCode)
                        }
                        
                        if !vscodeInstallLog.isEmpty {
                            if isInstallingVSCode {
                                ProgressView("Deploying Extensions...")
                                    .padding(.vertical, 5)
                                    .controlSize(.small)
                            } else {
                                Text("Deployment Finished!")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            
                            ScrollView {
                                Text(vscodeInstallLog)
                                    .font(.system(size: 9, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(5)
                            }
                            .frame(height: 60)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                        
                        Divider().padding(.vertical, 10)
                            
                        Button("Next Step") { selectedTab = 2 }
                            .buttonStyle(.borderedProminent)
                    } else {
                        if !awInstallLog.isEmpty {
                            if isInstallingAW {
                                ProgressView("Installing via Homebrew...")
                                    .padding(.bottom, 5)
                            } else {
                                Text("Installation Complete!")
                                    .font(.headline)
                                    .padding(.bottom, 5)
                            }
                            
                            ScrollView {
                                Text(awInstallLog)
                                    .font(.system(size: 10, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            }
                            .frame(height: 120)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                        
                        if !isInstallingAW {
                            HStack(spacing: 15) {
                                Button("Install ActivityWatch") { installAW() }
                                    .buttonStyle(.borderedProminent)
                                Button("Check Connection") { checkAW() }
                                    .buttonStyle(.borderedProminent).tint(.green)
                            }
                        }
                        
                        if let error = awError {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                    }
                }
                .onAppear(perform: checkAW)
                
            } else if selectedTab == 2 {
                // STEP 2: Calendar
                VStack(spacing: 20) {
                    Image(systemName: "calendar")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Calendar Integration").font(.title).bold()
                    Text("Allow access to your calendar so the local AI knows about upcoming meetings to add context.")
                        .multilineTextAlignment(.center).padding(.horizontal)
                    
                    if calendarAuthorized {
                        Text("✅ Calendar Access Granted!")
                            .foregroundColor(.green)
                            .font(.headline)
                        Button("Next Step") { selectedTab = 3 }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Grant Calendar Access") {
                            Task {
                                let granted = await CalendarService.shared.requestAccess()
                                await MainActor.run { calendarAuthorized = granted }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Skip for now") { selectedTab = 3 }
                            .buttonStyle(.borderless)
                    }
                }
                .onAppear {
                    calendarAuthorized = CalendarService.shared.isAuthorized
                }
                
            } else if selectedTab == 3 {
                // STEP 3: Ollama
                VStack(spacing: 20) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    Text("Ollama Local AI").font(.title).bold()
                    Text("Ollama runs LLMs strictly on your machine to analyze windows and derive task suggestions.")
                        .multilineTextAlignment(.center).padding(.horizontal)
                    
                    if ollamaRunning {
                        Text("✅ Ollama is running!")
                            .foregroundColor(.green)
                            .font(.headline)
                        
                        if availableModels.isEmpty {
                            Text("No models found. Please pull one.")
                                .font(.caption)
                        } else {
                            Picker("Select Model", selection: $selectedModel) {
                                ForEach(availableModels, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 300)
                            
                            Divider().padding(.vertical, 5)
                        }
                        
                        if isPulling {
                            ProgressView("Pulling \(newModelToPull)...")
                        } else {
                            HStack {
                                TextField("e.g. llama3.2:3b", text: $newModelToPull)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                                Button("Pull / Download") { pullModel() }
                            }
                        }
                        
                        Spacer()
                        Button("Finish Setup") {
                            if !selectedModel.isEmpty {
                                UserDefaults.standard.set(selectedModel, forKey: "OllamaModelName")
                            }
                            isOnboardingComplete = true
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedModel.isEmpty && availableModels.isEmpty && !isPulling)
                        
                    } else {
                        if !ollamaInstallLog.isEmpty {
                            if isInstallingOllama {
                                ProgressView("Installing via Homebrew...")
                                    .padding(.bottom, 5)
                            } else {
                                Text("Installation Complete!")
                                    .font(.headline)
                                    .padding(.bottom, 5)
                            }
                            
                            ScrollView {
                                Text(ollamaInstallLog)
                                    .font(.system(size: 10, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                            }
                            .frame(height: 120)
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                        }
                        
                        if !isInstallingOllama {
                            HStack(spacing: 15) {
                                Button("Install Ollama") { installOllama() }
                                    .buttonStyle(.borderedProminent)
                                Button("Check Connection") { checkOllama() }
                                    .buttonStyle(.borderedProminent).tint(.green)
                            }
                        }
                    }
                }
                .onAppear(perform: checkOllama)
            }
        }
        .padding()
        }
    }
    
    // --- Actions ---
    
    func enforceAWInputConfig() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let awQtDir = home.appendingPathComponent("Library/Application Support/activitywatch/aw-qt")
        let tomlPath = awQtDir.appendingPathComponent("aw-qt.toml")
        
        do {
            try FileManager.default.createDirectory(at: awQtDir, withIntermediateDirectories: true, attributes: nil)
            let content = """
            [aw-qt]
            autostart_modules = ["aw-server", "aw-watcher-afk", "aw-watcher-window", "aw-watcher-input"]
            """
            try content.write(to: tomlPath, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to enforce toml config: \(error)")
        }
    }
    
    func checkAW() {
        Task {
            let running = await ActivityWatchClient.shared.checkDaemonStatus()
            await MainActor.run { self.awRunning = running }
        }
    }
    
    func installVSCodeAW() {
        isInstallingVSCode = true
        vscodeInstallLog = "Starting IDE extension deployment...\n"
        
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            let extensionsCmd = "code --install-extension ActivityWatch.aw-watcher-vscode; cursor --install-extension ActivityWatch.aw-watcher-vscode; agy --install-extension ActivityWatch.aw-watcher-vscode"
            process.arguments = ["-c", "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"; \(extensionsCmd)"]
            
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { return }
                if let str = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.vscodeInstallLog += str
                    }
                }
            }
            
            process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    self.isInstallingVSCode = false
                    self.vscodeInstallLog += "\n✅ Deployment pipeline closed."
                }
            }
            
            try? process.run()
        }
    }
    
    func installAW() {
        isInstallingAW = true
        awInstallLog = "Connecting to Homebrew...\n"
        awError = nil
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-c", "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"; brew install --cask activitywatch && open -a ActivityWatch"]
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        self.awInstallLog += str
                    }
                }
            }
            
            process.terminationHandler = { p in
                pipe.fileHandleForReading.readabilityHandler = nil
                Task { @MainActor in
                    if p.terminationStatus == 0 {
                        self.awInstallLog += "\n✅ Installation finished! ActivityWatch is launching...\nIMPORTANT: ActivityWatch requires Accessibility permissions to function.\nPlease look for any macOS security popups and click 'Allow' or manually verify it in System Settings.\n\nThen click 'Check Connection' below to proceed."
                    } else {
                        self.awError = "Brew failed. Install manually."
                    }
                    self.isInstallingAW = false
                }
            }
            
            do {
                try process.run()
            } catch {
                self.awError = error.localizedDescription
                self.isInstallingAW = false
            }
        }
    }
    
    func checkOllama() {
        Task {
            let running = await OllamaClient.shared.checkDaemonStatus()
            if running {
                let models = await OllamaClient.shared.fetchLocalModels()
                await MainActor.run {
                    self.ollamaRunning = true
                    self.availableModels = models
                    if let first = models.first {
                        self.selectedModel = first
                    }
                }
            } else {
                await MainActor.run { self.ollamaRunning = false }
            }
        }
    }
    
    func installOllama() {
        isInstallingOllama = true
        ollamaInstallLog = "Connecting to Homebrew...\n"
        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", "export PATH=\"/opt/homebrew/bin:/usr/local/bin:$PATH\"; brew install --cask ollama && open -a Ollama"]
            let pipe = Pipe()
            process.standardError = pipe
            process.standardOutput = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        self.ollamaInstallLog += str
                    }
                }
            }
            
            process.terminationHandler = { p in
                pipe.fileHandleForReading.readabilityHandler = nil
                Task { @MainActor in
                    if p.terminationStatus == 0 {
                        self.ollamaInstallLog += "\n✅ Installation finished! Ollama is launching...\n\nClick 'Check Connection' below to proceed."
                    }
                    self.isInstallingOllama = false
                }
            }
            
            do {
                try process.run()
            } catch {
                self.isInstallingOllama = false
            }
        }
    }
    
    func pullModel() {
        isPulling = true
        Task {
            let success = await OllamaClient.shared.pullModel(name: newModelToPull)
            let models = await OllamaClient.shared.fetchLocalModels()
            await MainActor.run {
                self.availableModels = models
                if success || models.contains(newModelToPull) {
                    self.selectedModel = newModelToPull
                    self.newModelToPull = ""
                }
                self.isPulling = false
            }
        }
    }
}
