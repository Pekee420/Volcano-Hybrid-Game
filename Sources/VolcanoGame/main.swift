import SwiftUI

// Initialize BluetoothManager as normal
let bluetoothManager = BluetoothManager.shared

// BluetoothManager will auto-initialize and start scanning

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 App launched - BluetoothManager initialized")
        // Force a scan check after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔄 Checking Bluetooth state after launch...")
            let state = BluetoothManager.shared.centralManager.state
            print("🔍 Bluetooth state on launch: \(state.rawValue)")
            if state == .poweredOn {
                print("✅ Bluetooth powered on - forcing scan")
                BluetoothManager.shared.startScanning()
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        print("🎯 App became active - checking Bluetooth")
        // Additional check when app becomes active
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if BluetoothManager.shared.centralManager.state == .poweredOn && !BluetoothManager.shared.isScanning {
                print("✅ App active - Bluetooth ready, starting scan")
                BluetoothManager.shared.startScanning()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)

let contentView = ContentView()

print("🏁 Creating window and starting app")

let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)

window.center()
window.title = "Volcano Game"
window.contentView = NSHostingView(rootView: contentView)
window.makeKeyAndOrderFront(nil)

print("🏁 Window created and shown")
app.activate(ignoringOtherApps: true)
print("🏁 App activated, starting run loop")
app.run()
