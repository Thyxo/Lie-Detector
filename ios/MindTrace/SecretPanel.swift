import SwiftUI
import PhotosUI

struct SecretPanel: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var s: AppSettings
    @State private var openedAt = Date()
    @State private var photo: PhotosPickerItem?
    @State private var showAdvanced = false
    @State private var icon: AppIconChoice = .fingerprint
    @State private var iconError = false

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                sensitivitySection
                modeSection
                looksSection
                advancedSection
                Section {
                    Button(s.tr("Nulstil til start", "Back to start")) { engine.resetToStart() }
                } footer: {
                    Text(s.tr("Åbn menuen: 5 hurtige tryk øverst til højre.", "Open menu: 5 quick taps top right."))
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
        .onAppear { openedAt = Date(); icon = AppIconChoice.current }
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
            Text(s.tr("Udslag under tærsklen = ingen mønt (1 bump). Vibrerer den \"mønt\" for tit: skru op. Opdager den ikke mønten: skru ned – eller brug \"Lær min mønt\".",
                      "Signals below the threshold = no coin (1 buzz). Too many false coins: raise it. Misses the coin: lower it – or use \"Learn my coin\"."))
        }
    }

    // MARK: Vibration + tilstand
    private var modeSection: some View {
        Section {
            Picker(s.tr("Tilstand", "Mode"), selection: $s.mode) {
                Text("Normal").tag(AppMode.normal)
                Text(s.tr("Hemmelig", "Secret")).tag(AppMode.hidden)
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading) {
                Text(String(format: s.tr("Vibration starter efter %.1f s", "Vibration starts after %.1f s"), s.vibDelay))
                Slider(value: $s.vibDelay, in: 0...5, step: 0.5)
            }
            HStack {
                Button(s.tr("Test: mønt (2)", "Test: coin (2)")) { engine.haptics.pulses(2) }
                Spacer()
                Button(s.tr("Test: ingen (1)", "Test: none (1)")) { engine.haptics.pulses(1) }
            }
            .buttonStyle(.borderless)
            if s.mode == .hidden {
                PhotosPicker(selection: $photo, matching: .images) {
                    Text(s.hasBackground ? s.tr("Skift billede", "Change image") : s.tr("Vælg billede (fx din hjemmeskærm)", "Choose image (e.g. your home screen)"))
                }
                if s.hasBackground {
                    Button(s.tr("Brug sort skærm", "Use black screen")) { BackgroundStore.clear(); s.hasBackground = false }
                }
            }
        } header: { Text(s.tr("Vibration og tilstand", "Vibration and mode")) } footer: {
            Text(s.mode == .hidden
                 ? s.tr("Sort skærm (eller dit billede). Tryk for at scanne. Telefonen vibrerer: 2 bump = mønt, 1 bump = ingen mønt – hvert sekund, indtil du trykker igen.",
                        "Black screen (or your image). Tap to scan. The phone buzzes: 2 = coin, 1 = no coin – every second until you tap again.")
                 : s.tr("Tryk på startskærmen → Tænker. Telefonen vibrerer: 2 bump = mønt, 1 bump = ingen mønt (1 lang = ingen sensordata), hvert sekund. Tilskueren svarer – du trykker volumen op = Sandt, ned = Falsk. Trykker du forkert, så tryk den anden knap.",
                        "Tap the start screen → Thinking. The phone buzzes: 2 = coin, 1 = no coin (1 long = no sensor data), every second. The spectator answers – you press volume up = True, down = False. Wrong button? Press the other one."))
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
            iconPicker
        }
    }

    // MARK: App-ikon
    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s.tr("App-ikon", "App icon"))
            HStack(spacing: 12) {
                ForEach(AppIconChoice.allCases) { c in
                    Button {
                        let previous = icon
                        icon = c
                        c.apply { ok in if !ok { icon = previous; iconError = true } }
                    } label: {
                        VStack(spacing: 4) {
                            Image(c.preview)
                                .resizable()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(icon == c ? Color.accentColor : .clear, lineWidth: 3))
                            Text(c.label(s)).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            if iconError {
                Text(s.tr("Ikonet kunne ikke skiftes.", "Could not change the icon.")).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Avanceret
    private var advancedSection: some View {
        Section {
            DisclosureGroup(s.tr("Avanceret", "Advanced"), isExpanded: $showAdvanced) {
                Stepper(s.tr("Målinger i træk: \(s.consecutive)", "Samples in a row: \(s.consecutive)"), value: $s.consecutive, in: 1...20)
                Picker(s.tr("Måling", "Measuring"), selection: $s.sensorMode) {
                    Text(s.tr("Auto (tåler drejning)", "Auto (ignores turning)")).tag(SensorMode.auto)
                    Text(s.tr("Rå (hold roligt)", "Raw (hold still)")).tag(SensorMode.raw)
                }
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
