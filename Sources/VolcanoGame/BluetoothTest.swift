//
//  BluetoothTest.swift
//  VolcanoGame
//

import CoreBluetooth
import Foundation

class BluetoothTest: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothTest()
    private var centralManager: CBCentralManager!
    var testComplete = false

    private override init() {
        super.init()
        print("🧪 BluetoothTest: Creating CBCentralManager")
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func runTest() {
        print("🧪 BluetoothTest: Starting test scan")
        testComplete = false

        // Test immediate state
        let state = centralManager.state
        print("🧪 BluetoothTest: Initial state = \(state.rawValue)")

        if state == .poweredOn {
            print("🧪 BluetoothTest: Powered on, starting scan")
            centralManager.scanForPeripherals(withServices: nil, options: nil)

            // Stop after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                print("🧪 BluetoothTest: Stopping scan")
                self.centralManager.stopScan()
                self.testComplete = true
                print("🧪 BluetoothTest: Test complete")
            }
        } else {
            print("🧪 BluetoothTest: Not powered on (state: \(state.rawValue))")
            testComplete = true
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🧪 BluetoothTest: centralManagerDidUpdateState called - state: \(central.state.rawValue)")
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("🧪 BluetoothTest: DISCOVERED - \(peripheral.name ?? "Unknown") [\(peripheral.identifier.uuidString.prefix(8))] RSSI: \(RSSI)")
    }
}
