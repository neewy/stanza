# Contributing to Stanza

First off, thank you for considering contributing to Stanza! It's people like you that make the open-source community such a great place to learn, inspire, and create.

## 🛠 Development Setup

Stanza is a native macOS application built with **SwiftUI** and **SwiftData**.

### 1. Prerequisites
- **Xcode 15.0+**
- **macOS 14.0+**
- **Homebrew** (for managing dependencies)

### 2. Building from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/stanza.git
   cd stanza
   ```
2. Open the project in Xcode:
   ```bash
   open Package.swift
   ```
   *Note: If you are using a standard Xcode Project (.xcodeproj), open that instead.*

3. **Entitlements & Sandbox**:
   - Stanza requires the **App Sandbox to be disabled** to interact with the Homebrew-installed `brew` binary for the onboarding wizard.
   - Ensure the **Calendars** capability is added to your target's "Signing & Capabilities" tab.

4. **Run**: Press `Cmd + R` to build and run the application.

## 🧪 Testing
- Current tests are located in the `Tests/` directory (if applicable).
- Run tests using `Cmd + U`.

## 📬 Reporting Issues
- Use the **Bug Report** template for technical issues.
- Use the **Feature Request** template for new ideas.
- Provide as much context as possible, including your macOS version and hardware (Intel vs. Apple Silicon).

## 🗺 Roadmap
- [ ] Support for custom LLM endpoints (OpenAI/Anthropic).
- [ ] Export to CSV/JSON for data nerds.
- [ ] Menu Bar widgets for quick category switching.

## ⚖️ License
By contributing, you agree that your contributions will be licensed under its [MIT License](LICENSE).
