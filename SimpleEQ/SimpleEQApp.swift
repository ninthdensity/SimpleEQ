import AppKit
import SwiftUI

@main
struct SimpleEQApp: App {
    @StateObject private var model = AppModel()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("SimpleEQ", id: "main") {
            ContentView(appDelegate: appDelegate)
                .environmentObject(model)
        }
        .defaultSize(width: 600, height: 640)
        .windowStyle(.hiddenTitleBar)
        .commands {
            SimpleEQCommands()
        }

        MenuBarExtra("SimpleEQ", systemImage: "slider.horizontal.3") {
            ContentView(showsOpenWindowButton: true)
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct SimpleEQCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .newItem) { }
        CommandGroup(after: .windowList) {
            Button("Show SimpleEQ Window") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut("0", modifiers: [.command])
        }
    }
}

func styleMainWindow() {
    guard let window = NSApp.windows.first(where: {
        $0.title == "SimpleEQ" || $0.identifier?.rawValue.contains("main") == true
    }) else { return }
    window.isOpaque = false
    window.titlebarAppearsTransparent = true
    window.backgroundColor = .clear
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var showMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow?()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
