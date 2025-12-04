//
//  BluetoothManager.swift
//  VolcanoGame
//

import CoreBluetooth
import Foundation

class BluetoothManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    static let shared = BluetoothManager()

    private var _centralManager: CBCentralManager!
    private var _volcanoPeripheral: CBPeripheral?

    // Volcano BLE UUIDs
    private let volcanoServiceUUIDs = [
        CBUUID(string: "10110000-5354-4F52-5A26-4249434B454C"), // Air pump service
        CBUUID(string: "10100000-5354-4f52-5a26-4249434b454c"),  // Main service
    ]

    // Air pump characteristics
    private let airOnUUID = CBUUID(string: "10110013-5354-4F52-5A26-4249434B454C")
    private let airOffUUID = CBUUID(string: "10110014-5354-4F52-5A26-4249434B454C")

    // Fan control characteristics
    private let fanOnUUID = CBUUID(string: "10110011-5354-4F52-5A26-4249434B454C")
    private let fanOffUUID = CBUUID(string: "10110012-5354-4F52-5A26-4249434B454C")

    // Temperature characteristics (from Volcano Hybrid BLE protocol)
    private let tempWriteUUID = CBUUID(string: "10110003-5354-4F52-5A26-4249434B454C") // Write target temp
    private let tempReadUUID = CBUUID(string: "10110001-5354-4F52-5A26-4249434B454C")  // Read current temp
    
    // Heater control characteristics (Volcano Hybrid)
    private let heaterOnUUID = CBUUID(string: "1011000F-5354-4F52-5A26-4249434B454C")  // Turn heater on
    private let heaterOffUUID = CBUUID(string: "10110010-5354-4F52-5A26-4249434B454C") // Turn heater off
    // Alternative heater UUIDs to try
    private let heaterOnAltUUID = CBUUID(string: "10110005-5354-4F52-5A26-4249434B454C")
    private let heaterOffAltUUID = CBUUID(string: "10110006-5354-4F52-5A26-4249434B454C")

    private var airOnCharacteristic: CBCharacteristic?
    private var airOffCharacteristic: CBCharacteristic?
    private var fanOnCharacteristic: CBCharacteristic?
    private var fanOffCharacteristic: CBCharacteristic?
    private var tempWriteCharacteristic: CBCharacteristic?
    private var tempReadCharacteristic: CBCharacteristic?
    private var heaterOnCharacteristic: CBCharacteristic?
    private var heaterOffCharacteristic: CBCharacteristic?
    private var heaterOnAltCharacteristic: CBCharacteristic?
    private var heaterOffAltCharacteristic: CBCharacteristic?
    
    @Published var currentTemperature: Int = 0
    private var targetTemperature: Int = 180
    private var lastTemperature: Int = 0
    private var heaterAutoManage: Bool = true // Auto-manage heater during gameplay

    @Published var discoveredDevices: [(peripheral: CBPeripheral, rssi: Int, name: String)] = []

    var volcanoPeripheral: CBPeripheral? {
        return _volcanoPeripheral
    }

    var centralManager: CBCentralManager {
        return _centralManager
    }

    @Published var connectionState: String = "Not Connected"
    @Published var isConnected: Bool = false
    @Published var isScanning: Bool = false

    private func logDebugEvent(_ message: String, timestamp: Date = Date()) {
        let logMessage = "\(timestamp): \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            let fileURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent("VolcanoGame_Debug.log")
            if let fileURL = fileURL {
                do {
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let fileHandle = try FileHandle(forWritingTo: fileURL)
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    } else {
                        try data.write(to: fileURL)
                    }
                } catch {
                    print("❌ Failed to write debug log: \(error)")
                }
            }
        }
    }

    override init() {
        super.init()
        print("🔧 BluetoothManager init() called")
        _centralManager = CBCentralManager(delegate: self, queue: nil)
        print("🔧 CBCentralManager created")
        print("🔧 Initial Bluetooth state: \(_centralManager.state.rawValue)")

        // Start periodic state checking since delegate callbacks might be delayed
        startStateMonitoring()

        // Listen for the UI interaction that fixes Bluetooth
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerBluetoothFix),
            name: NSNotification.Name("TriggerBluetoothFix"),
            object: nil
        )
    }

    @objc private func triggerBluetoothFix() {
        print("🎯 Received Bluetooth fix trigger - forcing state refresh")
        checkAndHandleState()
        forceStateRefresh()
    }

    private func startStateMonitoring() {
        print("👀 Starting Bluetooth state monitoring")

        // Check state immediately
        checkAndHandleState()

        // Check again after short delays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkAndHandleState()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.checkAndHandleState()
        }

        // Continue monitoring periodically
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.startPeriodicMonitoring()
        }
    }

    private func checkAndHandleState() {
        let state = _centralManager.state
        print("🔍 State check - Bluetooth state: \(state.rawValue)")

        if state == .poweredOn && !BluetoothManager.shared.isScanning && _volcanoPeripheral == nil {
            print("✅ Bluetooth powered on and ready - starting scan")
            startScanning()
        }
    }

    private func startPeriodicMonitoring() {
        checkAndHandleState()

        // Continue checking every 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            self?.startPeriodicMonitoring()
        }
    }

    func startScanning() {
        print("🔍 startScanning called - state: \(_centralManager.state.rawValue), isScanning: \(isScanning)")
        guard _centralManager.state == .poweredOn else {
            print("❌ Cannot scan - Bluetooth not powered on (state: \(_centralManager.state.rawValue))")
            return
        }
        guard !BluetoothManager.shared.isScanning else {
            print("⚠️ Already scanning, skipping")
            return
        }
        BluetoothManager.shared.isScanning = true
        _centralManager.scanForPeripherals(withServices: nil, options: nil)
        connectionState = "Scanning for devices..."
        print("🔍 Started Bluetooth scan for all peripherals")
    }

    func stopScanning() {
        guard isScanning else { return }
        BluetoothManager.shared.isScanning = false
        _centralManager.stopScan()
        print("🛑 Stopped scanning")
    }

    func connect(to peripheral: CBPeripheral) {
        print("🔗 Connecting to: \(peripheral.name ?? "Unknown")")
        _volcanoPeripheral = peripheral
        _centralManager.connect(peripheral, options: nil)
        stopScanning()
    }

    func disconnect() {
        if let peripheral = _volcanoPeripheral {
            _centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func startAirPump() {
        let timestamp = Date()
        print("🚀 START AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)")
        logDebugEvent("🚀 START AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)", timestamp: timestamp)

        guard let characteristic = airOnCharacteristic, isConnected else {
            print("❌ CANNOT START AIR PUMP - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)")
            logDebugEvent("❌ CANNOT START AIR PUMP - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)", timestamp: timestamp)
            return
        }
        let data = Data([0x01])
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("🚀 AIR PUMP START SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)")
        logDebugEvent("🚀 AIR PUMP START SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)", timestamp: timestamp)
    }

    func stopAirPump() {
        let timestamp = Date()
        print("🛑 STOP AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil)")
        logDebugEvent("🛑 STOP AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil)", timestamp: timestamp)

        guard let characteristic = airOffCharacteristic, isConnected else {
            print("❌ CANNOT STOP AIR PUMP - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil)")
            logDebugEvent("❌ CANNOT STOP AIR PUMP - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil)", timestamp: timestamp)
            return
        }
        let data = Data([0x00]) // Use 0x00 to stop
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("🛑 AIR PUMP STOP SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)")
        logDebugEvent("🛑 AIR PUMP STOP SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)", timestamp: timestamp)
    }

    func startFan() {
        print("💨 startFan called - isConnected: \(isConnected), hasCharacteristic: \(fanOnCharacteristic != nil)")
        guard let characteristic = fanOnCharacteristic, isConnected else {
            print("❌ Cannot start fan - connected: \(isConnected), characteristic: \(fanOnCharacteristic != nil)")
            return
        }
        let data = Data([0x01])
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("💨 Fan START command sent: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)")
    }

    func stopFan() {
        print("🌀 stopFan called - isConnected: \(isConnected), hasCharacteristic: \(fanOffCharacteristic != nil)")
        guard let characteristic = fanOffCharacteristic, isConnected else {
            print("❌ Cannot stop fan - connected: \(isConnected), characteristic: \(fanOffCharacteristic != nil)")
            return
        }
        let data = Data([0x00]) // Use 0x00 to stop
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("🌀 Fan STOP command sent: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)")
    }
    
    // MARK: - Heater Control
    
    func startHeater() {
        print("🔥 startHeater called - isConnected: \(isConnected)")
        print("   heaterOn: \(heaterOnCharacteristic != nil), heaterOnAlt: \(heaterOnAltCharacteristic != nil)")
        
        guard isConnected else {
            print("❌ Cannot start heater - not connected")
            return
        }
        
        let data = Data([0x01])
        
        // Try primary heater characteristic
        if let characteristic = heaterOnCharacteristic {
            _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
            print("🔥 Heater START sent to PRIMARY: \(characteristic.uuid)")
        }
        
        // Also try alternative heater characteristic
        if let altCharacteristic = heaterOnAltCharacteristic {
            _volcanoPeripheral?.writeValue(data, for: altCharacteristic, type: .withResponse)
            print("🔥 Heater START sent to ALT: \(altCharacteristic.uuid)")
        }
        
        // If no heater characteristics found, try setting temperature (this often triggers heating)
        if heaterOnCharacteristic == nil && heaterOnAltCharacteristic == nil {
            print("⚠️ No heater characteristic found - trying temp write to trigger heating")
            setTemperature(targetTemperature)
        }
    }
    
    func stopHeater() {
        print("🔥 stopHeater called - isConnected: \(isConnected)")
        
        guard isConnected else {
            print("❌ Cannot stop heater - not connected")
            return
        }
        
        let data = Data([0x00])
        
        // Try primary heater characteristic
        if let characteristic = heaterOffCharacteristic {
            _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
            print("🔥 Heater STOP sent to PRIMARY: \(characteristic.uuid)")
        }
        
        // Also try alternative heater characteristic
        if let altCharacteristic = heaterOffAltCharacteristic {
            _volcanoPeripheral?.writeValue(data, for: altCharacteristic, type: .withResponse)
            print("🔥 Heater STOP sent to ALT: \(altCharacteristic.uuid)")
        }
    }

    // MARK: - Temperature Control
    
    func setTemperature(_ tempCelsius: Int) {
        print("🌡️ setTemperature called - temp: \(tempCelsius)°C, isConnected: \(isConnected), hasChar: \(tempWriteCharacteristic != nil)")
        guard let characteristic = tempWriteCharacteristic, isConnected else {
            print("❌ Cannot set temperature - connected: \(isConnected), characteristic: \(tempWriteCharacteristic != nil)")
            return
        }
        
        // Volcano uses temperature * 10 in little-endian format
        let tempValue = UInt32(tempCelsius * 10)
        var data = Data()
        data.append(UInt8(tempValue & 0xFF))
        data.append(UInt8((tempValue >> 8) & 0xFF))
        data.append(UInt8((tempValue >> 16) & 0xFF))
        data.append(UInt8((tempValue >> 24) & 0xFF))
        
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        targetTemperature = tempCelsius
        print("🌡️ Temperature SET command sent: \(tempCelsius)°C (0x\(data.map { String(format: "%02x", $0) }.joined())) to \(characteristic.uuid)")
        logDebugEvent("🌡️ Temperature SET: \(tempCelsius)°C")
    }
    
    func increaseTemperature() {
        let newTemp = min(targetTemperature + 5, 230)
        setTemperature(newTemp)
    }
    
    func decreaseTemperature() {
        let newTemp = max(targetTemperature - 5, 40)
        setTemperature(newTemp)
    }
    
    func readTemperature() {
        print("🌡️ readTemperature called - isConnected: \(isConnected), hasChar: \(tempReadCharacteristic != nil)")
        guard let characteristic = tempReadCharacteristic, isConnected else {
            print("❌ Cannot read temperature - connected: \(isConnected), characteristic: \(tempReadCharacteristic != nil)")
            return
        }
        _volcanoPeripheral?.readValue(for: characteristic)
        print("🌡️ Temperature READ request sent to \(characteristic.uuid)")
    }

    func forceStateRefresh() {
        print("🔄 Forcing Bluetooth state refresh...")
        if _centralManager.state == .poweredOn && !BluetoothManager.shared.isScanning && _volcanoPeripheral == nil {
            startScanning()
        }
    }

    func forceScan() {
        print("🔧 Forcing manual scan...")
        startScanning()
    }

    func forceDisconnect() {
        if let peripheral = _volcanoPeripheral {
            print("🔌 Force disconnecting from: \(peripheral.name ?? "Unknown")")
            _centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func debugConnection() {
        print("🔍 DEBUG: Bluetooth state: \(_centralManager.state.rawValue)")
        print("🔍 DEBUG: Volcano peripheral: \(_volcanoPeripheral?.name ?? "None")")
        print("🔍 DEBUG: Peripheral state: \(_volcanoPeripheral?.state.rawValue ?? -1)")
        print("🔍 DEBUG: Is connected: \(isConnected)")
        print("🔍 DEBUG: Is scanning: \(isScanning)")
        print("🔍 DEBUG: Discovered devices count: \(discoveredDevices.count)")
    }

    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔄 CBCentralManager didUpdateState called - state: \(central.state.rawValue)")
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth powered on - starting auto-scan")
            connectionState = "Scanning..."
            startScanning()
        case .poweredOff:
            print("❌ Bluetooth powered off")
            connectionState = "Bluetooth Off"
            isConnected = false
        case .resetting:
            print("🔄 Bluetooth resetting")
            connectionState = "Resetting..."
        case .unauthorized:
            print("🚫 Bluetooth unauthorized")
            connectionState = "Bluetooth Unauthorized"
        case .unsupported:
            print("🚫 Bluetooth unsupported")
            connectionState = "Bluetooth Unsupported"
        case .unknown:
            print("❓ Bluetooth state unknown")
            connectionState = "Bluetooth Unknown"
        @unknown default:
            print("❓ Bluetooth state: \(central.state.rawValue)")
            connectionState = "Bluetooth Issue"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        let identifier = peripheral.identifier.uuidString.prefix(8)

        if RSSI.intValue > -90 {
            let deviceInfo = (peripheral: peripheral, rssi: RSSI.intValue, name: name)
            if !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) {
                discoveredDevices.append(deviceInfo)
                print("📱 Found: \(name) [\(identifier)] RSSI: \(RSSI)")
            }
        }

        // Auto-connect to Volcano devices
        let upperName = name.uppercased()
        if upperName.contains("VOLCANO") || upperName.contains("S&B") {
            print("🌋 Found Volcano device - auto-connecting")
            connect(to: peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to: \(peripheral.name ?? "Unknown")")
        connectionState = "Connected"
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices(volcanoServiceUUIDs)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        connectionState = "Connection Failed"
        isConnected = false
        _volcanoPeripheral = nil
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("📴 Disconnected with error: \(error.localizedDescription)")
        } else {
            print("📴 Disconnected normally")
        }
        connectionState = "Disconnected"
        isConnected = false
        _volcanoPeripheral = nil
    }

    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Service discovery error: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            print("⚠️ No services found on peripheral")
            return
        }
        print("📋 Found \(services.count) services on \(peripheral.name ?? "Unknown")")

        for service in services {
            print("🔧 Service: \(service.uuid)")
            // Check if this is one of our expected services
            let isExpectedService = volcanoServiceUUIDs.contains(service.uuid)
            print("   Expected service: \(isExpectedService)")

            // Discover characteristics for this service
            peripheral.discoverCharacteristics(nil, for: service) // Discover ALL characteristics
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ Characteristic discovery error: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            print("📊 Characteristic: \(characteristic.uuid)")

            if characteristic.uuid == airOnUUID {
                airOnCharacteristic = characteristic
                print("✅ Found Air On characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == airOffUUID {
                airOffCharacteristic = characteristic
                print("✅ Found Air Off characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == fanOnUUID {
                fanOnCharacteristic = characteristic
                print("✅ Found Fan On characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == fanOffUUID {
                fanOffCharacteristic = characteristic
                print("✅ Found Fan Off characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == tempWriteUUID {
                tempWriteCharacteristic = characteristic
                print("✅ Found Temperature Write characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == tempReadUUID {
                tempReadCharacteristic = characteristic
                print("✅ Found Temperature Read characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.read) ? "R" : "-")\(characteristic.properties.contains(.notify) ? "N" : "-")")
                // Subscribe to temperature notifications if supported
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                // Read initial temperature
                peripheral.readValue(for: characteristic)
            } else if characteristic.uuid == heaterOnUUID {
                heaterOnCharacteristic = characteristic
                print("✅ Found Heater On characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == heaterOffUUID {
                heaterOffCharacteristic = characteristic
                print("✅ Found Heater Off characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == heaterOnAltUUID {
                heaterOnAltCharacteristic = characteristic
                print("✅ Found Heater On ALT characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == heaterOffAltUUID {
                heaterOffAltCharacteristic = characteristic
                print("✅ Found Heater Off ALT characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Write error for \(characteristic.uuid): \(error.localizedDescription)")
        } else {
            print("✅ Write successful for \(characteristic.uuid)")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Read error for \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value else {
            print("⚠️ No data received for \(characteristic.uuid)")
            return
        }

        if characteristic.uuid == tempReadUUID {
            // Parse temperature - Volcano sends as little-endian uint32 * 10
            var tempCelsius = 0
            if data.count >= 4 {
                let tempRaw = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
                tempCelsius = Int(tempRaw / 10)
                print("🌡️ Temperature read: \(tempCelsius)°C (raw: \(tempRaw))")
            } else if data.count >= 2 {
                // Try 2-byte format
                let tempRaw = UInt16(data[0]) | (UInt16(data[1]) << 8)
                tempCelsius = Int(tempRaw / 10)
                print("🌡️ Temperature read (2-byte): \(tempCelsius)°C (raw: \(tempRaw))")
            }
            
            // Detect temperature falloff - heater likely turned off
            DispatchQueue.main.async {
                let previousTemp = self.lastTemperature
                self.currentTemperature = tempCelsius
                
                // If temp dropped by 1°C or more and we have auto-manage enabled
                if self.heaterAutoManage && previousTemp > 0 && tempCelsius > 0 {
                    if previousTemp - tempCelsius >= 1 {
                        print("⚠️ Temperature falloff detected! \(previousTemp)°C → \(tempCelsius)°C - Turning heater back ON")
                        self.startHeater()
                        self.setTemperature(self.targetTemperature)
                    }
                }
                
                self.lastTemperature = tempCelsius
            }
        }
    }
    
    // Enable/disable automatic heater management
    func setHeaterAutoManage(_ enabled: Bool) {
        heaterAutoManage = enabled
        print("🔥 Heater auto-manage: \(enabled ? "ON" : "OFF")")
    }

}