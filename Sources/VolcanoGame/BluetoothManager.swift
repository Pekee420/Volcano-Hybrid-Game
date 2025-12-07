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

    // Boost control characteristics (NOT fan - these toggle heater boost mode!)
    private let boostOnUUID = CBUUID(string: "10110011-5354-4F52-5A26-4249434B454C")
    private let boostOffUUID = CBUUID(string: "10110012-5354-4F52-5A26-4249434B454C")

    // Temperature characteristics (from Volcano Hybrid BLE protocol)
    private let tempWriteUUID = CBUUID(string: "10110003-5354-4F52-5A26-4249434B454C") // Write target temp
    private let tempReadUUID = CBUUID(string: "10110001-5354-4F52-5A26-4249434B454C")  // Read current temp
    
    // Heater control characteristics (Volcano Hybrid)
    private let heaterOnUUID = CBUUID(string: "1011000F-5354-4F52-5A26-4249434B454C")  // Turn heater on
    private let heaterOffUUID = CBUUID(string: "10110010-5354-4F52-5A26-4249434B454C") // Turn heater off
    
    // LED Brightness characteristic
    private let ledBrightnessUUID = CBUUID(string: "10110005-5354-4F52-5A26-4249434B454C")

    private var airOnCharacteristic: CBCharacteristic?
    private var airOffCharacteristic: CBCharacteristic?
    private var boostOnCharacteristic: CBCharacteristic?
    private var boostOffCharacteristic: CBCharacteristic?
    private var tempWriteCharacteristic: CBCharacteristic?
    private var tempReadCharacteristic: CBCharacteristic?
    private var heaterOnCharacteristic: CBCharacteristic?
    private var heaterOffCharacteristic: CBCharacteristic?
    private var ledBrightnessCharacteristic: CBCharacteristic?
    
    @Published var currentBrightness: Int = 100  // 0-100%
    
    @Published var currentTemperature: Int = 0
    private var targetTemperature: Int = 180
    private var airPumpRunning: Bool = false

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
    
    // Allow heater start commands only when the current phase permits (set by GameState)
    var heaterCommandsAllowed: Bool = true
    // Track phase for logging/debug
    var currentPhase: String = "unknown"
    // Phases in which heater/temperature writes are allowed
    private let allowedHeaterPhases: Set<String> = ["setup/finished", "waitingForTemp"]
    // Track last known heater state to avoid sending toggle-on to an already-on heater
    private(set) var heaterIsOn: Bool = false
    private var lastTemperatureSetAt: Date?
    private var lastTemperatureValue: Int?
    
    // Rate limiting heater start commands to avoid rapid cycling
    private var lastHeaterStartAt: Date?
    private let minHeaterStartInterval: TimeInterval = 8.0

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

    private let bluetoothQueue = DispatchQueue(label: "com.volcanoblaze.bluetooth", qos: .userInitiated)
    private var hasInitialized = false
    
    override init() {
        super.init()
        print("🔧 BluetoothManager init() called")
        
        #if os(iOS)
        // On iOS, delay CBCentralManager creation to prevent startup lag
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.initializeBluetooth()
        }
        #else
        // On macOS, initialize immediately
        initializeBluetooth()
        #endif
    }
    
    private func initializeBluetooth() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        print("🔧 Initializing CBCentralManager...")
        _centralManager = CBCentralManager(delegate: self, queue: bluetoothQueue)
        print("🔧 CBCentralManager created on background queue")
        
        DispatchQueue.main.async {
            print("🔧 Initial Bluetooth state: \(self._centralManager.state.rawValue)")
        }

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
        // Ensure Bluetooth is initialized first
        guard hasInitialized else {
            print("⚠️ Bluetooth not yet initialized, deferring scan")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.startScanning()
            }
            return
        }
        
        print("🔍 startScanning called - state: \(_centralManager.state.rawValue), isScanning: \(isScanning)")
        guard _centralManager.state == .poweredOn else {
            print("❌ Cannot scan - Bluetooth not powered on (state: \(_centralManager.state.rawValue))")
            DispatchQueue.main.async {
                self.connectionState = "Bluetooth not ready"
            }
            return
        }
        guard !BluetoothManager.shared.isScanning else {
            print("⚠️ Already scanning, skipping")
            return
        }
        
        bluetoothQueue.async { [weak self] in
            guard let self = self else { return }
            BluetoothManager.shared.isScanning = true
            self._centralManager.scanForPeripherals(withServices: nil, options: nil)
            DispatchQueue.main.async {
                self.connectionState = "Scanning for devices..."
            }
            print("🔍 Started Bluetooth scan for all peripherals")
        }
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
        heaterIsOn = false
    }

    func disconnect() {
        if let peripheral = _volcanoPeripheral {
            _centralManager.cancelPeripheralConnection(peripheral)
        }
        heaterIsOn = false
    }

    func startAirPump() {
        let timestamp = Date()
        print("🚀 START AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)")
        logDebugEvent("🚀 START AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)", timestamp: timestamp)

        // Avoid redundant start commands while already running
        if airPumpRunning {
            print("⚠️ Air pump already running - start command skipped")
            logDebugEvent("⚠️ Air pump already running - start skipped", timestamp: timestamp)
            return
        }

        guard let characteristic = airOnCharacteristic, isConnected else {
            print("❌ CANNOT START AIR PUMP - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)")
            logDebugEvent("❌ CANNOT START AIR PUMP - Connected: \(isConnected), HasChar: \(airOnCharacteristic != nil)", timestamp: timestamp)
            return
        }
        airPumpRunning = true
        let data = Data([0x01])
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("🚀 AIR PUMP START SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)")
        logDebugEvent("🚀 AIR PUMP START SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)", timestamp: timestamp)
    }

    // Track if we should block pump stop during active gameplay
    var blockPumpStopDuringCycle = false
    
    func stopAirPump(force: Bool = false) {
        let timestamp = Date()
        print("🛑 STOP AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil), force: \(force), blockPumpStop: \(blockPumpStopDuringCycle)")
        logDebugEvent("🛑 STOP AIR PUMP CALLED - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil), force: \(force), blockPumpStop: \(blockPumpStopDuringCycle)", timestamp: timestamp)

        // Block pump stop during active cycle unless forced (cycle end)
        // This prevents rapid Air ON/OFF which triggers firmware heater toggle
        if blockPumpStopDuringCycle && !force {
            print("⚠️ Air pump stop BLOCKED during active cycle (prevents heater toggle)")
            logDebugEvent("⚠️ Air pump stop BLOCKED during active cycle (prevents heater toggle)", timestamp: timestamp)
            return
        }

        // Avoid redundant stop commands when already stopped
        if !airPumpRunning {
            print("⚠️ Air pump already stopped - stop command skipped")
            logDebugEvent("⚠️ Air pump already stopped - stop skipped", timestamp: timestamp)
            return
        }

        guard let characteristic = airOffCharacteristic, isConnected else {
            print("❌ CANNOT STOP AIR PUMP - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil)")
            logDebugEvent("❌ CANNOT STOP AIR PUMP - Connected: \(isConnected), HasChar: \(airOffCharacteristic != nil)", timestamp: timestamp)
            return
        }
        let data = Data([0x00]) // Use 0x00 to stop
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("🛑 AIR PUMP STOP SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)")
        logDebugEvent("🛑 AIR PUMP STOP SENT: 0x\(data.map { String(format: "%02x", $0) }.joined()) to \(characteristic.uuid)", timestamp: timestamp)
        airPumpRunning = false
    }

    // MARK: - LED Brightness Control
    
    func setBrightness(_ percent: Int) {
        print("💡 setBrightness called - value: \(percent)%, isConnected: \(isConnected), hasCharacteristic: \(ledBrightnessCharacteristic != nil)")
        guard let characteristic = ledBrightnessCharacteristic, isConnected else {
            print("❌ Cannot set brightness - connected: \(isConnected), characteristic: \(ledBrightnessCharacteristic != nil)")
            return
        }
        
        // Clamp to 0-100
        let clampedPercent = max(0, min(100, percent))
        
        // Volcano uses direct percent value as UInt16 little-endian (0-100)
        let brightnessValue = UInt16(clampedPercent)
        var value = brightnessValue.littleEndian
        let data = Data(bytes: &value, count: 2)
        
        _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
        print("💡 Brightness SET: \(clampedPercent)% (raw bytes: \(data.map { String(format: "%02x", $0) }.joined())) to \(characteristic.uuid)")
        
        // Save to UserDefaults
        UserDefaults.standard.set(clampedPercent, forKey: "volcanoBrightness")
        
        DispatchQueue.main.async {
            self.currentBrightness = clampedPercent
        }
    }
    
    // MARK: - Heater Control
    
    // Flag to prevent heater commands during active gameplay
    var blockHeaterCommands = false
    // Extra guard to completely freeze heater state during cycle (start/stop ignored)
    var heaterLockedDuringCycle = false
    
    func startHeater() {
        print("🔥 startHeater called - isConnected: \(isConnected), blocked: \(blockHeaterCommands), locked: \(heaterLockedDuringCycle), pumpRunning: \(airPumpRunning), phase: \(currentPhase)")
        print("   heaterOn: \(heaterOnCharacteristic != nil)")
        
        guard !blockHeaterCommands else {
            print("⚠️ Heater command blocked (blockHeaterCommands=true) phase: \(currentPhase)")
            logDebugEvent("⚠️ Heater start blocked (blockHeaterCommands=true) phase: \(currentPhase)")
            return
        }
        
        guard !heaterLockedDuringCycle else {
            print("⚠️ Heater start ignored (heaterLockedDuringCycle=true)")
            logDebugEvent("⚠️ Heater start ignored (locked during cycle) phase: \(currentPhase)")
            return
        }
        
        guard heaterCommandsAllowed else {
            print("⚠️ Heater start ignored (heaterCommandsAllowed=false) phase: \(currentPhase)")
            logDebugEvent("⚠️ Heater start ignored (phase disallows heater) phase: \(currentPhase)")
            return
        }
        
        // Explicit phase allowlist: only setup/finished/waitingForTemp may start heater
        if !allowedHeaterPhases.contains(currentPhase) {
            print("⚠️ Heater start ignored (phase not allowed): \(currentPhase)")
            logDebugEvent("⚠️ Heater start ignored (phase not allowed): \(currentPhase)")
            return
        }

        // If we already believe heater is on, do not send another start (heater toggles)
        if heaterIsOn {
            print("⚠️ Heater start skipped - heaterIsOn flag true (avoid toggle)")
            logDebugEvent("⚠️ Heater start skipped - heaterIsOn=true (avoid toggle)")
            return
        }
        
        // Rate-limit heater start to prevent rapid on/off toggling
        let now = Date()
        if let last = lastHeaterStartAt, now.timeIntervalSince(last) < minHeaterStartInterval {
            let delta = now.timeIntervalSince(last)
            print("⚠️ Heater start skipped - rate limited (\(String(format: "%.1f", delta))s since last)")
            logDebugEvent("⚠️ Heater start skipped - rate limited (\(String(format: "%.1f", delta))s since last)")
            return
        }
        
        guard isConnected else {
            print("❌ Cannot start heater - not connected")
            return
        }
        
        let data = Data([0x01])
        
        // Try primary heater characteristic
        if let characteristic = heaterOnCharacteristic {
            _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
            print("🔥 Heater START sent to PRIMARY: \(characteristic.uuid)")
            logDebugEvent("🔥 Heater START sent to PRIMARY: \(characteristic.uuid)")
        } else {
            // If no heater characteristic found, try setting temperature (this often triggers heating)
            print("⚠️ No heater characteristic found - trying temp write to trigger heating")
            setTemperature(targetTemperature)
        }
        
        lastHeaterStartAt = now
        heaterIsOn = true
    }
    
    func stopHeater() {
        print("🔥 stopHeater called - isConnected: \(isConnected), blocked: \(blockHeaterCommands), locked: \(heaterLockedDuringCycle), pumpRunning: \(airPumpRunning), phase: \(currentPhase)")
        
        guard allowedHeaterPhases.contains(currentPhase) else {
            print("⚠️ Heater stop ignored (phase not allowed): \(currentPhase)")
            logDebugEvent("⚠️ Heater stop ignored (phase not allowed): \(currentPhase)")
            return
        }
        
        guard isConnected else {
            print("❌ Cannot stop heater - not connected")
            return
        }
        
        let data = Data([0x00])
        
        // Try primary heater characteristic
        if let characteristic = heaterOffCharacteristic {
            _volcanoPeripheral?.writeValue(data, for: characteristic, type: .withResponse)
            print("🔥 Heater STOP sent to PRIMARY: \(characteristic.uuid)")
            logDebugEvent("🔥 Heater STOP sent to PRIMARY: \(characteristic.uuid)")
        }

        heaterIsOn = false
    }

    // MARK: - Temperature Control
    
    func setTemperature(_ tempCelsius: Int) {
        print("🌡️ setTemperature called - temp: \(tempCelsius)°C, isConnected: \(isConnected), hasChar: \(tempWriteCharacteristic != nil), locked: \(heaterLockedDuringCycle), pumpRunning: \(airPumpRunning), phase: \(currentPhase)")

        // Only allow temp writes in allowed heater phases (setup/finished/waitingForTemp)
        if !allowedHeaterPhases.contains(currentPhase) {
            print("⚠️ Ignoring setTemperature in disallowed phase: \(currentPhase)")
            logDebugEvent("⚠️ Ignored setTemperature \(tempCelsius) (phase \(currentPhase))")
            return
        }

        // Rate-limit identical temperature commands to avoid device toggling
        let now = Date()
        if let lastVal = lastTemperatureValue,
           lastVal == tempCelsius,
           let lastAt = lastTemperatureSetAt,
           now.timeIntervalSince(lastAt) < 8.0 {
            print("⚠️ Skipping duplicate setTemperature \(tempCelsius) (rate limited)")
            logDebugEvent("⚠️ Skipped duplicate setTemperature \(tempCelsius) (rate limited)")
            return
        }
        
        guard !heaterLockedDuringCycle else {
            print("⚠️ Ignoring temperature set while heaterLockedDuringCycle")
            logDebugEvent("⚠️ Ignored setTemperature \(tempCelsius) (locked during cycle)")
            return
        }
        
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
        lastTemperatureValue = tempCelsius
        lastTemperatureSetAt = now
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
            } else if characteristic.uuid == boostOnUUID {
                boostOnCharacteristic = characteristic
                print("✅ Found Boost On characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.writeWithoutResponse) ? "WNR" : "-")")
            } else if characteristic.uuid == boostOffUUID {
                boostOffCharacteristic = characteristic
                print("✅ Found Boost Off characteristic: \(characteristic.uuid)")
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
            } else if characteristic.uuid == ledBrightnessUUID {
                ledBrightnessCharacteristic = characteristic
                print("✅ Found LED Brightness characteristic: \(characteristic.uuid)")
                print("   Properties: \(characteristic.properties.contains(.write) ? "W" : "-")\(characteristic.properties.contains(.read) ? "R" : "-")")
                // Read current brightness
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
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
            
            // Update temperature - only auto-manage heater during waitingForTemp phase
            DispatchQueue.main.async {
                self.currentTemperature = tempCelsius
                // Heater auto-manage is now handled by WaitingForTempView only
            }
        } else if characteristic.uuid == ledBrightnessUUID {
            // Parse brightness - stored as UInt16 little-endian (0-100 direct percent)
            if data.count >= 2 {
                let brightnessRaw = UInt16(data[0]) | (UInt16(data[1]) << 8)
                let brightnessPercent = Int(brightnessRaw)
                print("💡 Brightness read: \(brightnessPercent)% (raw: \(brightnessRaw))")
                DispatchQueue.main.async {
                    self.currentBrightness = brightnessPercent
                }
            }
        }
    }
    
}