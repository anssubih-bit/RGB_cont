import CoreBluetooth
import Foundation

@MainActor
final class StripController: NSObject, ObservableObject {
    enum State: Equatable { case off, idle, scanning, connecting(String), connected(String) }

    @Published var state: State = .idle
    @Published var found: [CBPeripheral] = []

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private let targets: [(service: CBUUID, char: CBUUID)] = [
        (CBUUID(string: "FFF0"), CBUUID(string: "FFF3")),
        (CBUUID(string: "FFE0"), CBUUID(string: "FFE1")),
    ]
    private let namePrefixes = ["ELK", "LEDBLE", "BLEDOM", "MELK", "LEDBlue", "QHM"]
    private let lastKey = "lastPeripheral"

    // Throttle: fast slider/drag updates keep only the latest frame per control.
    private var pending: [String: Data] = [:]
    private var flushScheduled = false

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var isConnected: Bool { if case .connected = state { return true }; return false }

    func scan() {
        guard central.state == .poweredOn else { return }
        found = []
        state = .scanning
        central.scanForPeripherals(withServices: nil, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self, self.state == .scanning else { return }
            self.central.stopScan(); self.state = .idle
        }
    }

    func connect(_ p: CBPeripheral) {
        central.stopScan()
        peripheral = p
        p.delegate = self
        state = .connecting(p.name ?? "strip")
        central.connect(p)
    }

    func disconnect() { if let p = peripheral { central.cancelPeripheralConnection(p) } }

    func send(_ data: Data, coalesce key: String? = nil) {
        guard let key else { write(data); return }
        pending[key] = data
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self else { return }
            self.flushScheduled = false
            let frames = self.pending; self.pending = [:]
            frames.values.forEach(self.write)
        }
    }

    private func write(_ data: Data) {
        guard let p = peripheral, let c = characteristic else { return }
        let type: CBCharacteristicWriteType = c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(data, for: c, type: type)
    }
}

extension StripController: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            guard central.state == .poweredOn else { state = .off; return }
            state = .idle
            // Reconnect to the last strip automatically.
            if let s = UserDefaults.standard.string(forKey: lastKey), let id = UUID(uuidString: s),
               let p = central.retrievePeripherals(withIdentifiers: [id]).first {
                connect(p)
            } else {
                scan()
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
            // Show every named device (the strip never appears in iOS Settings > Bluetooth),
            // with names that look like LED controllers listed first.
            guard !name.isEmpty, !found.contains(where: { $0.identifier == peripheral.identifier }) else { return }
            if namePrefixes.contains(where: { name.uppercased().hasPrefix($0.uppercased()) }) {
                found.insert(peripheral, at: 0)
            } else {
                found.append(peripheral)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated { peripheral.discoverServices(targets.map(\.service)) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { state = .idle }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { characteristic = nil; state = .idle }
    }
}

extension StripController: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            for s in peripheral.services ?? [] {
                if let t = targets.first(where: { $0.service == s.uuid }) {
                    peripheral.discoverCharacteristics([t.char], for: s)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        MainActor.assumeIsolated {
            guard characteristic == nil,
                  let c = service.characteristics?.first(where: { ch in targets.contains { $0.char == ch.uuid } })
            else { return }
            characteristic = c
            UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: lastKey)
            state = .connected(peripheral.name ?? "strip")
        }
    }
}
