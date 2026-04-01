# Stanza: Privacy-First AI Time Tracking for macOS

![Stanza Banner](https://raw.githubusercontent.com/placeholder-stanza-banner.png)

> **"What did I actually do today?"** 

Stanza is a native macOS application that silently observes your active window context and intelligently suggests meaningful task summaries using local AI. It bridges the gap between chaotic deep-work sessions and structured time logs—all without your data ever leaving your machine.

---

## ✨ Key Features

- **🪄 AI-Powered Context**: Automatically generates 2-3 word task descriptions based on your active windows, calendar events, and app usage patterns.
- **🔒 100% Local Intelligence**: Powered by **Ollama**. Your activity data is analyzed by local LLMs (like Llama 3) on your own Apple Silicon. No cloud, no tracking, no privacy tradeoffs.
- **📊 Elegant Visualization**: Built with native SwiftUI Charts to provide beautiful, actionable insights into where your time is invested.
- **🕒 Timeline of Truth**: Integrates with **ActivityWatch** to show you exactly which apps you were using during a specific timer entry.
- **⚡️ Zero-Config Onboarding**: An integrated setup wizard helps you install dependencies via Homebrew and get tracking in under 60 seconds.

## 🚀 Getting Started

### 📦 Installation (Recommended)
1. Download the latest `Stanza.dmg` from the [Releases](https://github.com/yourusername/stanza/releases) page.
2. Drag **Stanza.app** to your Applications folder.
3. Open the app and follow the **Onboarding Wizard** to install ActivityWatch and Ollama.

> [!TIP]
> Since Stanza is an unsigned developer build, you may need to right-click the app and choose "Open" or run `xattr -dr com.apple.quarantine /Applications/Stanza.app` in your Terminal if you encounter a Gatekeeper warning.

### 🛠 Manual Build
If you'd like to build Stanza from source, please see our [Contributing Guide](CONTRIBUTING.md).

## 🛠 Prerequisites
Stanza relies on two open-source giants to provide its core functionality:
- **[ActivityWatch](https://activitywatch.net/)**: For local window and input telemetry.
- **[Ollama](https://ollama.com/)**: For running the local Large Language Models.

The built-in wizard can handle these installations for you automatically.

## 🛡 Privacy & Security
We believe your time is your most private asset. 
- **No Analytics**: We don't track how you use Stanza.
- **No Cloud**: AI processing happens on your GPU via Ollama.
- **Local Storage**: All tracking data is stored in a local SwiftData/SQLite database on your Mac.

## 📄 License
Stanza is released under the [MIT License](LICENSE).

---
*Crafted with ❤️ for the macOS community.*
