import SwiftUI

struct SecretPanel: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var settings: AppSettings
    @State private var openedAt = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(badge.text).font(.headline).foregroundStyle(badge.color)
                        Spacer()
                        if let a = engine.armed { Text("Klar: \(a.label)").foregroundStyle(.secondary) }
                    }
                    row("Kilde", engine.sensor.activeSource)
                    row("Kalibrering", engine.sensor.accuracy)
                    row("Felt |B|", fmt(engine.liveField))
                    row("Grundmåling", fmt(engine.liveBaseline))
                    if let ref = engine.liveReference, let f = engine.liveField {
                        let d = f - ref
                        HStack {
                            Text("Δ fra reference")
                            Spacer()
                            Text(String(format: "%+.1f µT", d)).monospacedDigit()
                            Text(abs(d) >= settings.threshold ? "MAGNET" : "–")
                                .foregroundStyle(abs(d) >= settings.threshold ? Color.falsk : Color.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                    Button("Sæt reference (hold telefonen væk fra magneten)") { engine.setReference() }
                } header: { Text("Sensor-test") } footer: {
                    Text("Sæt reference, og før derefter magneten hen mod toppen af telefonen. Se hvor stor Δ bliver, og indstil tærsklen derefter.")
                }

                Section("Afgørelse") {
                    Toggle("Automatisk sensor (magnet = Falsk)", isOn: $settings.autoSensor)
                    Toggle("Volumenknapper (op = Sandt, ned = Falsk)", isOn: $settings.volumeButtons)
                    Toggle("Lille vibration ved knaptryk", isOn: $settings.haptic)
                    Toggle("Diskret prik når knap er trykket", isOn: $settings.dot)
                    Picker("Uden sensordata", selection: $settings.fallback) {
                        Text("Sandt").tag(Verdict.sandt)
                        Text("Falsk").tag(Verdict.falsk)
                    }
                }

                Section {
                    VStack(alignment: .leading) {
                        Text("Tærskel: \(Int(settings.threshold)) µT")
                        Slider(value: $settings.threshold, in: 5...300, step: 1)
                    }
                    Stepper("Målinger i træk: \(settings.consecutive)", value: $settings.consecutive, in: 2...20)
                    Picker("Sensorkilde", selection: $settings.source) {
                        ForEach(SensorSource.allCases) { Text($0.label).tag($0) }
                    }
                } header: { Text("Sensor") } footer: {
                    Text("Grundmålingen tages automatisk lige før Tænker starter. Hold telefonen væk fra magneten, når du trykker.")
                }

                Section("Tænker") {
                    VStack(alignment: .leading) {
                        Text(String(format: "Mindst %.1f s", settings.thinkMin))
                        Slider(value: $settings.thinkMin, in: 1...8, step: 0.5)
                    }
                    VStack(alignment: .leading) {
                        Text(String(format: "Højst %.1f s", settings.thinkMax))
                        Slider(value: $settings.thinkMax, in: 1...8, step: 0.5)
                    }
                }

                Section("Log") {
                    if engine.log.isEmpty { Text("—").foregroundStyle(.secondary) }
                    ForEach(engine.log) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.time, style: .time).font(.caption2).foregroundStyle(.secondary)
                            Text(e.text).font(.caption)
                        }
                    }
                }

                Section {
                    Button("Nulstil til start") { engine.resetToStart() }
                    Button("PANIK – kun ærlig sensor", role: .destructive) { engine.panic() }
                } footer: {
                    Text("Åbn: 5 hurtige tryk øverst til højre. Panik: hold nederste venstre hjørne på startskærmen i ¾ s.")
                }
            }
            .navigationTitle("MindTrace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Færdig") {
                        // Første sekund ignoreres, så et ekstra hemmeligt tryk ikke lukker panelet.
                        if Date().timeIntervalSince(openedAt) > 1 { engine.panelOpen = false }
                    }
                }
            }
        }
        .onAppear { openedAt = Date(); engine.setReference() }
    }

    private var badge: (text: String, color: Color) {
        if !engine.sensor.hardwareAvailable { return ("INGEN SENSOR", .falsk) }
        if !engine.sensorLive { return ("VENTER PÅ SENSOR", .orange) }
        return ("SENSOR KLAR", .green)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary).monospacedDigit() }
    }

    private func fmt(_ v: Double?) -> String { v.map { String(format: "%.1f µT", $0) } ?? "—" }
}
