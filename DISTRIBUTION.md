# Distribution Guide: How to Install Stanza

Since this app is distributed outside of the Apple Developer Program, Apple's Gatekeeper will initially block it from running. Follow these steps to install and open the app:

## Step 1: Download and Extract
1. Download the `Stanza.dmg` or `Stanza.zip`.
2. Open the DMG and drag **Stanza** to your **Applications** folder.

## Step 2: Open the App (The First Time)
If you double-click the app, you may see a warning: *"Stanza cannot be opened because the developer cannot be verified."*

### Preferred Method (Right-Click)
1. Locate **Stanza** in your Applications folder.
2. **Right-click** (or Control-click) the app icon and select **Open**.
3. A different dialog will appear with an **Open** button. Click it.
4. The app will now be remembered as safe and will open normally in the future.

### Alternative Method (System Settings)
1. Double-click the app and click **Cancel** on the warning dialog.
2. Open **System Settings > Privacy & Security**.
3. Scroll down to the **Security** section.
4. You will see a message: *"Stanza was blocked from use because it is not from an identified developer."*
5. Click **Open Anyway**.
6. Enter your password or use Touch ID to confirm.

---

## Why am I seeing this?
This app is self-signed to ensure the code hasn't been tampered with since it was built. However, because the developer has not paid for an official Apple Developer ID, Apple hasn't "notarized" the binary. This is common for many indie and open-source macOS tools.
