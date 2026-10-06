# Todoy ⏱️

A sleek, AMOLED-friendly, gesture-driven daily task manager for iOS built natively with SwiftUI. Designed with minimalist aesthetics, fluid micro-interactions, liquid-glass contextual menus, and tactile haptic feedback.

---

## ✨ Features

- 🖤 **AMOLED & Dark Mode First**: Designed for deep OLED blacks and clean light mode ergonomics, reducing visual clutter.
- 📅 **Today & Upcoming Separation**: Focus strictly on what needs to get done today while effortlessly scheduling future items for upcoming days.
- 🫧 **Liquid Glass Context Menu**: Long-press any task to trigger a custom floating frosted-glass (`.ultraThinMaterial`) menu with smooth spring physics.
- 🔗 **Smart Link Detection**: Automatically detects URLs in your task titles with a direct one-tap shortcut to open them in Safari.
- 📋 **Batch Paste from Clipboard**: Copy multi-line lists from Notes or messages and paste them directly into Todoy with one tap.
- 📳 **Tactile Haptic Feedback**: Every action—tapping, completing, starring, and deleting—is paired with tuned iOS haptics (`UIImpactFeedbackGenerator`).
- 🎨 **Color Coding & Importance**: Highlight high-priority items with custom color accents (Standard, Red, Blue, Green, Orange) and swipe-to-star actions.
- 🦄 **Sticker Studio & Floating Canvas**: Express yourself by placing, dragging, and pinning die-cut Apple & developer stickers anywhere on your screen.
- 📊 **Insights & History**: Review your completed task archive and keep track of your daily productivity momentum.
- 🔒 **100% Offline & Private**: Zero tracking, zero cloud accounts required. Your data stays securely on your device using local `UserDefaults` persistence.

---

## 📱 Gesture & Interaction Guide

| Action | Gesture / Trigger | Description |
| :--- | :--- | :--- |
| **Complete Task** | Single Tap | Marks task as completed with strikethrough animation |
| **Quick Actions** | Long Press | Opens floating liquid-glass contextual action menu |
| **Mark Important** | Swipe Right | Quickly toggle high-priority / starred status |
| **Delete Task** | Swipe Left | Delete a task from the list |
| **Sticker Studio** | Bottom Sticker Button / Long Press `+` | Opens the liquid-glass Sticker Studio drawer |
| **Place Sticker** | Tap or Drag from Drawer | Place stickers anywhere on the screen |
| **Move Sticker** | Drag on Screen | Freely reposition any placed sticker |
| **Resize Sticker** | Pinch In / Out | Scale sticker smoothly between 0.35x and 4.0x |
| **Rotate Sticker** | Two-Finger Twist | Angle and tilt sticker naturally |
| **Delete Sticker** | Tap to Select -> (X) Button | Delete sticker or clear all from drawer |
| **Batch Paste / Insights** | Long Press `+` | Opens clipboard paste, sticker studio, and completion history |

---

## 🛠️ Technology Stack

- **Language:** Swift 5.0
- **Framework:** SwiftUI
- **Target OS:** iOS 18.0+ / iPadOS
- **Storage:** Local JSON Persistence (`UserDefaults` + `Codable`)
- **System Frameworks:** `UIKit`, `UserNotifications`

---

## 🚀 Getting Started

### Prerequisites
- macOS Sequoia (or latest compatible macOS)
- Xcode 16.0 or newer
- iOS 18.0+ Simulator or physical device

### Building & Running

1. **Clone the repository:**
   ```bash
   git clone https://github.com/sadewasadewal/Todoy.git
   cd Todoy
   ```

2. **Open the project in Xcode:**
   ```bash
   open Marker.xcodeproj
   ```

3. **Build and Run:**
   - Select your target simulator (e.g., iPhone 16 Pro) or your connected physical iOS device.
   - Press **Cmd + R** or click the **Play** button to build and run.

---

## 📂 Project Structure

```text
Todoy/
├── Marker/
│   ├── MarkerApp.swift       # App lifecycle & root splash view
│   ├── ContentView.swift     # Core SwiftUI views, models & liquid-glass menus
│   └── Assets.xcassets/      # App icons, colors, and asset catalog
├── Marker.xcodeproj          # Xcode project configuration
└── .gitignore                # Clean Xcode & OS file exclusions
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

Made with ❤️ by [Sandew Hiruditha](https://github.com/sadewasadewal)
