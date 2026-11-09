import SwiftUI

struct ContentView: View {
    @EnvironmentObject var strip: StripController
    @AppStorage("altPower") private var altPower = false
    @AppStorage("brightness") private var brightness = 100.0
    @AppStorage("speed") private var speed = 50.0
    @State private var color = Color(red: 1, green: 0.2, blue: 0.4)
    @State private var isOn = true
    @State private var activeEffect: UInt8?

    private let swatches: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .white]

    var body: some View {
        NavigationStack {
            List {
                connectionSection
                if strip.isConnected {
                    Section {
                        Toggle(isOn: $isOn) { Label("Power", systemImage: "power") }
                            .onChange(of: isOn) { _, v in strip.send(v ? LED.powerOn(alt: altPower) : LED.powerOff(alt: altPower)) }
                    }
                    Section("Color") {
                        ColorPicker("Pick a color", selection: $color, supportsOpacity: false)
                            .onChange(of: color) { _, c in sendColor(c) }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
                            ForEach(swatches.indices, id: \.self) { i in
                                Circle().fill(swatches[i]).frame(height: 32)
                                    .onTapGesture { color = swatches[i] }
                            }
                        }.padding(.vertical, 4)
                    }
                    Section("Brightness \(Int(brightness))%") {
                        Slider(value: $brightness, in: 0...100, step: 1)
                            .onChange(of: brightness) { _, v in strip.send(LED.brightness(UInt8(v)), coalesce: "bri") }
                    }
                    Section("Effects") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                            ForEach(LED.effects, id: \.code) { e in
                                Button(e.name) {
                                    activeEffect = e.code
                                    strip.send(LED.effect(e.code))
                                    strip.send(LED.speed(UInt8(speed)))
                                }
                                .buttonStyle(.bordered)
                                .tint(activeEffect == e.code ? .cyan : .gray)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Speed \(Int(speed))").font(.caption).foregroundStyle(.secondary)
                            Slider(value: $speed, in: 0...100, step: 1)
                                .onChange(of: speed) { _, v in strip.send(LED.speed(UInt8(v)), coalesce: "spd") }
                        }
                    }
                    Section {
                        Toggle("Alternate power command", isOn: $altPower)
                    } footer: {
                        Text("Turn this on if the power switch doesn't work with your controller.")
                    }
                }
            }
            .navigationTitle("Strip Control")
        }
    }

    @ViewBuilder private var connectionSection: some View {
        Section {
            switch strip.state {
            case .off:
                Text("Turn on Bluetooth and allow access in Settings.")
            case .idle:
                Button("Scan for strips") { strip.scan() }
                deviceList
            case .scanning:
                HStack { ProgressView(); Text("Scanning…") }
                deviceList
            case .connecting(let name):
                HStack { ProgressView(); Text("Connecting to \(name)…") }
            case .connected(let name):
                HStack {
                    Label(name, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    Spacer()
                    Button("Disconnect") { strip.disconnect() }
                }
            }
        }
    }

    private var deviceList: some View {
        ForEach(strip.found, id: \.identifier) { p in
            Button(p.name ?? "Unknown") { strip.connect(p) }
        }
    }

    private func sendColor(_ c: Color) {
        activeEffect = nil
        let ui = UIColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let clamp = { (x: CGFloat) in UInt8(max(0, min(255, (x * 255).rounded()))) }
        strip.send(LED.color(r: clamp(r), g: clamp(g), b: clamp(b)), coalesce: "color")
    }
}
