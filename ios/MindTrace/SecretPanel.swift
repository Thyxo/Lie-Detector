import SwiftUI
import PhotosUI

struct SecretPanel: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var s: AppSettings
    @State private var openedAt = Date()
    @State private var photo: PhotosPickerItem?
    @State private var showAdvanced = false

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                sensitivitySection
                decisionSection
                modeSection
                looksSection
                advancedSection
                Section {
                    Button(s.tr("Nulstil til start", "Back to start")) { engine.resetToStart() }
                    Button(s.tr("PANIK – kun ærlig sensor", "PANIC – honest sensor only"), role: .destructive) { engine.panic() }
                } footer: {
                    Text(s.tr("Åbn menuen: 5 hurtige tryk øverst til højre. Panik: hold nederste venstre hjørne på startskærmen i ¾ s.",
                              "Open menu: 5 quick taps top right. Panic: hold the bottom-left corner of the start screen for ¾ s."))
                }
            }
            .navigationTitle("MindTrace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(s.tr("Færdig", "Done")) {
                        // Første sekund ignoreres, så et ekstra hemmeligt tryk ikke lukker menuen.
                        if Date().timeIntervalSince(openedAt) > 1 { engine.panelOpen = false }
                    }
                }
            }
        }
        .onAppear { openedAt = Date() }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), BackgroundStore.save(data) {
                    await MainActor.run { s.hasBackground = true; s.backgroundVersion += 1 }
                }
            }
        }
    }

    // MARK: Status + live-måler
    private var statusSection: some View {
        Section {
            HStack {
                Text(badge.text).font(.headline).foregroundStyle(badge.color)
                Spacer()
                if let a = engine.armed { Text(s.tr("Klar: ", "Armed: ") + s.word(a)).foregroundStyle(.secondary) }
            }
            LiveMeter(value: engine.liveAnomaly ?? 0, peak: engine.liveMax, threshold: s.threshold, live: engine.sensorLive)
            Button(s.tr("Nulstil måling", "Reset reading")) { engine.resetLive() }
        } header: { Text(s.tr("Sensor", "Sensor")) } footer: {
            Text(s.tr("Viser udslaget lige nu. Før toppen af telefonen hen over mønten og se, om bjælken går over stregen (tærsklen).",
                      "Shows the signal right now. Move the top of the phone over the coin and check that the bar passes the line (threshold)."))
        }
    }

    private var badge: (text: String, color: Color) {
        if !engine.sensor.hardwareAvailable { return (s.tr("INGEN SENSOR", "NO SENSOR"), .red) }
        if !engine.sensorLive { return (s.tr("VENTER PÅ SENSOR", "WAITING FOR SENSOR"), .orange) }
        return (s.tr("SENSOR KLAR", "SENSOR READY"), .green)
    }

    // MARK: Følsomhed
    private var sensitivitySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(s.tr("Tærskel", "Threshold"))
                    Spacer()
                    Text("\(Int(s.threshold)) µT").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $s.threshold, in: 5...300, step: 1)
                HStack {
                    Text(s.tr("Mere følsom", "More sensitive")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(s.tr("Mindre følsom", "Less sensitive")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(s.tr("Standard (\(Int(AppSettings.defaultThreshold)) µT)", "Default (\(Int(AppSettings.defaultThreshold)) µT)")) {
                s.threshold = AppSettings.defaultThreshold
            }
            NavigationLink(s.tr("Lær min mønt (anbefalet)", "Learn my coin (recommended)")) {
                LearnView().environmentObject(engine).environmentObject(s)
            }
        } header: { Text(s.tr("Følsomhed", "Sensitivity")) } footer: {
            Text(s.tr("Udslag under tærsklen = ingen magnet. Siger den magnet for tit: skru op. Opdager den ikke mønten: skru ned – eller brug \"Lær min mønt\".",
                      "Signals below the threshold = no magnet. Too many false magnets: raise it. Misses the coin: lower it – or use \"Learn my coin\"."))
        }
    }

    // MARK: Afgørelse
    private var decisionSection: some View {
        Section(s.tr("Afgørelse", "Decision")) {
            Toggle(s.tr("Automatisk sensor", "Automatic sensor"), isOn: $s.autoSensor)
            Picker(s.tr("Magnet betyder", "Magnet means"), selection: $s.magnetMeans) {
                Text(s.word(.falsk)).tag(Verdict.falsk)
                Text(s.word(.sandt)).tag(Verdict.sandt)
            }
            Toggle(s.tr("Volumenknapper (op = Sandt, ned = Falsk)", "Volume buttons (up = True, down = False)"), isOn: $s.volumeButtons)
        }
    }

    // MARK: Tilstand
    private var modeSection: some View {
        Section {
            Picker(s.tr("Tilstand", "Mode"), selection: $s.mode) {
                Text("Normal").tag(AppMode.normal)
                Text(s.tr("Hemmelig vibration", "Secret vibration")).tag(AppMode.hidden)
            }
            .pickerStyle(.segmented)
            if s.mode == .hidden {
                Picker(s.tr("Gentag", "Repeat"), selection: $s.vibRepeat) {
                    Text(s.tr("5 gange", "5 times")).tag(VibRepeat.five)
                    Text(s.tr("Til jeg trykker", "Until I tap")).tag(VibRepeat.untilTap)
                }
                PhotosPicker(selection: $photo, matching: .images) {
                    Text(s.hasBackground ? s.tr("Skift billede", "Change image") : s.tr("Vælg billede (fx din hjemmeskærm)", "Choose image (e.g. your home screen)"))
                }
                if s.hasBackground {
                    Button(s.tr("Brug sort skærm", "Use black screen")) { BackgroundStore.clear(); s.hasBackground = false }
                }
                HStack {
                    Button(s.tr("Test Falsk (1)", "Test False (1)")) { engine.haptics.pulses(1) }
                    Spacer()
                    Button(s.tr("Test Sandt (2)", "Test True (2)")) { engine.haptics.pulses(2) }
                }
                .buttonStyle(.borderless)
            }
        } header: { Text(s.tr("Tilstand", "Mode")) } footer: {
            Text(s.mode == .hidden
                 ? s.tr("Tryk på skærmen for at scanne. Telefonen vibrerer svaret til dig: 1 gang = Falsk, 2 gange = Sandt, med 1 sekunds pause. Tryk igen for at stoppe.",
                        "Tap the screen to scan. The phone buzzes the answer to you: 1 = False, 2 = True, with a 1 second pause. Tap again to stop.")
                 : s.tr("Tilskueren ser Tænker og derefter Sandt eller Falsk.", "The spectator sees Thinking, then True or False."))
        }
    }

    // MARK: Udseende
    private var looksSection: some View {
        Section(s.tr("Udseende og lyd", "Look and sound")) {
            Picker(s.tr("Sprog", "Language"), selection: $s.language) {
                Text("Dansk").tag(AppLanguage.da)
                Text("English").tag(AppLanguage.en)
            }
            .pickerStyle(.segmented)
            Toggle(s.tr("Lyd ved Sandt/Falsk", "Sound on True/False"), isOn: $s.sound)
            HStack {
                Button(s.tr("Hør Sandt", "Play True")) { engine.sounds.play(.sandt) }
                Spacer()
                Button(s.tr("Hør Falsk", "Play False")) { engine.sounds.play(.falsk) }
            }
            .buttonStyle(.borderless)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(AppFont.allCases) { f in
                    Button { s.font = f } label: {
                        VStack(spacing: 4) {
                            Text(s.word(.sandt)).font(f.font(22)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                            Text(f.displayName).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.2)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(s.font == f ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: Avanceret
    private var advancedSection: some View {
        Section {
            DisclosureGroup(s.tr("Avanceret", "Advanced"), isExpanded: $showAdvanced) {
                VStack(alignment: .leading) {
                    Text(String(format: s.tr("Tænker mindst %.1f s", "Thinking at least %.1f s"), s.thinkMin))
                    Slider(value: $s.thinkMin, in: 1...8, step: 0.5)
                }
                VStack(alignment: .leading) {
                    Text(String(format: s.tr("Tænker højst %.1f s", "Thinking at most %.1f s"), s.thinkMax))
                    Slider(value: $s.thinkMax, in: 1...8, step: 0.5)
                }
                Stepper(s.tr("Målinger i træk: \(s.consecutive)", "Samples in a row: \(s.consecutive)"), value: $s.consecutive, in: 1...20)
                Picker(s.tr("Måling", "Measuring"), selection: $s.sensorMode) {
                    Text(s.tr("Auto (tåler drejning)", "Auto (ignores turning)")).tag(SensorMode.auto)
                    Text(s.tr("Rå (hold roligt)", "Raw (hold still)")).tag(SensorMode.raw)
                }
                Picker(s.tr("Uden sensordata", "Without sensor data"), selection: $s.fallback) {
                    Text(s.word(.sandt)).tag(Verdict.sandt)
                    Text(s.word(.falsk)).tag(Verdict.falsk)
                }
                Toggle(s.tr("Lille vibration ved knaptryk", "Small buzz on button press"), isOn: $s.haptic)
                Toggle(s.tr("Diskret prik når knap er trykket", "Discreet dot when button pressed"), isOn: $s.dot)
                HStack { Text(s.tr("Kalibrering", "Calibration")); Spacer(); Text(engine.sensor.accuracy).foregroundStyle(.secondary) }
                HStack { Text(s.tr("Målinger/s", "Samples/s")); Spacer(); Text("\(engine.sensor.rate)").foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Log").font(.subheadline.bold())
                    if engine.log.isEmpty { Text("—").foregroundStyle(.secondary) }
                    ForEach(engine.log) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.time, style: .time).font(.caption2).foregroundStyle(.secondary)
                            Text(e.text).font(.caption)
                        }
                    }
                }
            }
        }
    }
}

/// Bjælke: udslag nu, top-markør og tærskel-streg.
struct LiveMeter: View {
    @EnvironmentObject var s: AppSettings
    let value: Double
    let peak: Double
    let threshold: Double
    let live: Bool

    var body: some View {
        let scale = max(threshold * 2, 10)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(live ? String(format: "%.0f µT", value) : "—").font(.title2.monospacedDigit().bold())
                Spacer()
                Text(value >= threshold && live ? "MAGNET" : s.tr("ingen magnet", "no magnet"))
                    .font(.headline)
                    .foregroundStyle(value >= threshold && live ? Color.red : Color.secondary)
            }
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.22))
                    Capsule().fill(value >= threshold ? Color.red : Color.sandt)
                        .frame(width: w * min(1, value / scale))
                    Rectangle().fill(Color.white.opacity(0.5)).frame(width: 2)
                        .offset(x: w * min(1, peak / scale) - 1)
                    Rectangle().fill(Color.white).frame(width: 3, height: 22)
                        .offset(x: w * min(1, threshold / scale) - 1.5)
                }
            }
            .frame(height: 14)
            Text(s.tr("Top: \(Int(peak)) µT · tærskel: \(Int(threshold)) µT", "Peak: \(Int(peak)) µT · threshold: \(Int(threshold)) µT"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// "Lær min mønt": måler udslag uden og med mønt og sætter tærsklen.
struct LearnView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var s: AppSettings

    var body: some View {
        Form {
            Section {
                Text(s.tr("1. Hold telefonen væk fra mønten. Tryk Start og bevæg telefonen roligt rundt i 3 sekunder, som når du optræder.",
                          "1. Keep the phone away from the coin. Tap Start and move the phone around gently for 3 seconds, like when performing."))
                Button(engine.learnRunning && engine.learnStep == .noise ? s.tr("Måler …", "Measuring …") : s.tr("Start uden mønt", "Start without coin")) {
                    engine.learn(.noise)
                }
                .disabled(engine.learnRunning)
                if let n = engine.learnNoise { Text(s.tr("Uden mønt: \(Int(n)) µT", "Without coin: \(Int(n)) µT")).foregroundStyle(.secondary) }
            }
            Section {
                Text(s.tr("2. Læg mønten i en lukket hånd. Tryk Start, og før toppen af telefonen hen over hånden i 3 sekunder.",
                          "2. Put the coin in a closed hand. Tap Start and move the top of the phone over the hand for 3 seconds."))
                Button(engine.learnRunning && engine.learnStep == .coin ? s.tr("Måler …", "Measuring …") : s.tr("Start med mønt", "Start with coin")) {
                    engine.learn(.coin)
                }
                .disabled(engine.learnRunning || engine.learnNoise == nil)
                if let c = engine.learnCoin { Text(s.tr("Med mønt: \(Int(c)) µT", "With coin: \(Int(c)) µT")).foregroundStyle(.secondary) }
            }
            if let m = engine.learnMessage {
                Section { Text(m).font(.headline) }
            }
            Section {
                Button(s.tr("Start forfra", "Start over")) { engine.resetLearn() }
            }
        }
        .navigationTitle(s.tr("Lær min mønt", "Learn my coin"))
        .onAppear { engine.resetLearn() }
    }
}
