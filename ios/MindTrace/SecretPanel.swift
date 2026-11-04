import SwiftUI
import PhotosUI

/// Hemmelig menu. Åbnes med 5 hurtige tryk øverst til højre.
/// Rækkefølge: det man bruger oftest øverst (lyd, vibration, magnet), finpudsning nederst.
/// Live-målingen ligger i `LiveReadout`, så kun bjælken tegnes om 10 gange i sekundet.
struct SecretPanel: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var s: AppSettings
    @State private var openedAt = Date()
    @State private var photo: PhotosPickerItem?
    @State private var showAdvanced = false
    @State private var icon: AppIconChoice = .fingerprint
    @State private var iconError = false
    @State private var photoError = false

    var body: some View {
        NavigationStack {
            Form {
                soundSection
                vibrationSection
                magnetSection
                textsSection
                modeSection
                looksSection
                advancedSection
                Section {
                    Button { engine.resetToStart() } label: {
                        Label(s.tr("Tilbage til startskærmen", "Back to start screen"), systemImage: "arrow.uturn.backward")
                    }
                } footer: {
                    Text(s.tr("Åbn menuen: 5 hurtige tryk øverst til højre.", "Open this menu: 5 quick taps top right."))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(s.tr("Indstillinger", "Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(s.tr("Færdig", "Done")) {
                        // Første sekund ignoreres, så et ekstra hemmeligt tryk ikke lukker menuen.
                        if Date().timeIntervalSince(openedAt) > 1 { engine.panelOpen = false }
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("doneButton")
                }
            }
        }
        .tint(Color.sandt)
        .preferredColorScheme(.dark)
        .onAppear { openedAt = Date(); icon = AppIconChoice.current }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    if let data, BackgroundStore.save(data) {
                        photoError = false
                        s.hasBackground = true
                        s.backgroundVersion += 1
                    } else {
                        photoError = true
                    }
                    photo = nil
                }
            }
        }
    }

    // MARK: 1. Lyd
    private var soundSection: some View {
        Section {
            Toggle(isOn: $s.sound) {
                RowLabel(s.tr("Lyd", "Sound"), icon: "speaker.wave.2.fill", color: .orange)
            }
            .accessibilityIdentifier("soundToggle")
            if s.sound {
                ValueSlider(title: s.tr("Lydstyrke", "Volume"),
                            value: $s.soundVolume, range: 0...1, step: 0.05,
                            text: "\(Int((s.soundVolume * 100).rounded())) %",
                            sliderID: "volumeSlider", valueID: "volumeValue",
                            minIcon: "speaker.fill", maxIcon: "speaker.wave.3.fill")
                HStack(spacing: 10) {
                    PillButton(title: s.word(.sandt), icon: "play.fill", color: .sandt) {
                        engine.sounds.play(.sandt, volume: s.soundVolume)
                    }
                    PillButton(title: s.word(.falsk), icon: "play.fill", color: .falsk) {
                        engine.sounds.play(.falsk, volume: s.soundVolume)
                    }
                }
            }
        } header: {
            Text(s.tr("Lyd", "Sound"))
        }
    }

    // MARK: 2. Vibration
    private var vibrationSection: some View {
        Section {
            Toggle(isOn: $s.vibEnabled) {
                RowLabel(s.tr("Vibration", "Vibration"), icon: "iphone.radiowaves.left.and.right", color: .purple)
            }
            .accessibilityIdentifier("vibToggle")
            if s.vibEnabled {
                ValueSlider(title: s.tr("Styrke", "Strength"),
                            value: $s.vibStrength, range: 0.1...1, step: 0.05,
                            text: "\(Int((s.vibStrength * 100).rounded())) %",
                            sliderID: "vibStrengthSlider", valueID: "vibStrengthValue")
                ValueSlider(title: s.tr("Starter efter", "Starts after"),
                            value: $s.vibDelay, range: 0...5, step: 0.5,
                            text: String(format: "%.1f s", s.vibDelay),
                            sliderID: "vibDelaySlider", valueID: "vibDelayValue")
                HStack(spacing: 10) {
                    PillButton(title: s.tr("2 bump", "2 bumps"), icon: "hand.tap.fill", color: Color(white: 0.3)) {
                        engine.haptics.pulses(2, strength: s.vibStrength)
                    }
                    PillButton(title: s.tr("1 bump", "1 bump"), icon: "hand.tap.fill", color: Color(white: 0.3)) {
                        engine.haptics.pulses(1, strength: s.vibStrength)
                    }
                }
            }
        } header: {
            Text(s.tr("Vibration (kun du mærker den)", "Vibration (only you feel it)"))
        } footer: {
            Text(s.tr("2 bump = magnet i hånden · 1 bump = ingen magnet. Gentages hvert sekund.",
                      "2 bumps = magnet in the hand · 1 bump = no magnet. Repeats every second."))
        }
    }

    // MARK: 3. Magnet
    private var magnetSection: some View {
        Section {
            NavigationLink {
                LearnView().environmentObject(engine).environmentObject(s)
            } label: {
                HStack(spacing: 12) {
                    RowIcon(symbol: "wand.and.stars", color: .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.tr("Lær min magnet", "Learn my magnet")).fontWeight(.semibold)
                        Text(s.tr("Anbefalet · tager 10 sekunder", "Recommended · takes 10 seconds"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .accessibilityIdentifier("learnLink")

            LiveMeter(readout: engine.readout, threshold: s.threshold, hardware: engine.sensor.hardwareAvailable)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(s.tr("Følsomhed", "Sensitivity"))
                    Spacer()
                    Text("\(Int(s.threshold)) µT")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("thresholdValue")
                }
                Slider(value: $s.threshold, in: 5...300, step: 1)
                    .accessibilityIdentifier("thresholdSlider")
                HStack {
                    Text(s.tr("Fanger mere", "Catches more")).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if s.threshold != AppSettings.defaultThreshold {
                        Button(s.tr("Standard", "Default")) { s.threshold = AppSettings.defaultThreshold }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderless)
                        Spacer()
                    }
                    Text(s.tr("Fanger mindre", "Catches less")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Toggle(isOn: $s.coinDot) {
                RowLabel(s.tr("Hemmelig grå prik", "Secret grey dot"), icon: "circle.fill", color: .gray,
                         detail: s.tr("Vises øverst til venstre, når der er en magnet", "Shows top left when a magnet is found"))
            }
            .accessibilityIdentifier("dotToggle")
        } header: {
            Text(s.tr("Magnet", "Magnet"))
        } footer: {
            Text(s.tr("Test: før toppen af telefonen hen over magneten. Bjælken skal forbi den hvide streg. Siger den \"magnet\" for tit, så træk følsomheden mod højre.",
                      "Test: move the top of the phone over the magnet. The bar should pass the white line. If it says \"magnet\" too often, drag sensitivity to the right."))
        }
    }

    // MARK: 4. Resultattekster
    private var textsSection: some View {
        Section {
            HStack(spacing: 10) {
                ResultPreview(text: s.resultText(.sandt), color: .sandt, font: s.font)
                ResultPreview(text: s.resultText(.falsk), color: .falsk, font: s.font)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))

            resultField(.sandt, text: $s.customTrue, id: "customTrueField")
            resultField(.falsk, text: $s.customFalse, id: "customFalseField")

            VStack(alignment: .leading, spacing: 8) {
                Text(s.tr("Forslag", "Suggestions")).font(.caption).foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        PresetChip(t: s.word(.sandt), f: s.word(.falsk),
                                   selected: s.customTrue.isEmpty && s.customFalse.isEmpty) {
                            s.customTrue = ""; s.customFalse = ""
                        }
                        .accessibilityIdentifier("presetDefault")
                        ForEach(Array(presets.enumerated()), id: \.offset) { i, p in
                            PresetChip(t: p.0, f: p.1, selected: s.customTrue == p.0 && s.customFalse == p.1) {
                                s.customTrue = p.0; s.customFalse = p.1
                            }
                            .accessibilityIdentifier("preset\(i)")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(s.tr("Tekst på skærmen", "Text on screen"))
        } footer: {
            Text(s.tr("Skriv din egen, fx \"Afsløret!\". Tomt felt = standard.",
                      "Write your own, e.g. \"Busted!\". Empty field = default."))
        }
    }

    private var presets: [(String, String)] {
        s.language == .en
            ? [("TRUTH", "LIE!"), ("Honest", "Liar!"), ("✓", "✗"), ("Legit", "Busted!")]
            : [("SANDHED", "LØGN!"), ("Ærlig", "Lyver!"), ("✓", "✗"), ("Ægte", "Afsløret!")]
    }

    private func resultField(_ v: Verdict, text: Binding<String>, id: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(v == .sandt ? Color.sandt : Color.falsk)
                .frame(width: 22, height: 22)
            TextField(s.tr("Tekst ved \(s.word(v))", "Text for \(s.word(v))"), text: text)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityIdentifier(id)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: 5. Visning (Normal / Hemmelig)
    private var modeSection: some View {
        Section {
            Picker(s.tr("Visning", "Display"), selection: $s.mode) {
                Text("Normal").tag(AppMode.normal)
                Text(s.tr("Hemmelig", "Secret")).tag(AppMode.hidden)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .accessibilityIdentifier("modePicker")

            if s.mode == .normal {
                Toggle(isOn: $s.tapReveal) {
                    RowLabel(s.tr("Tryk for svar", "Tap to reveal"), icon: "hand.point.up.left.fill", color: .teal,
                             detail: s.tr("Øverste halvdel = Sandt · nederste = Falsk", "Top half = True · bottom half = False"))
                }
                .accessibilityIdentifier("tapRevealToggle")
                if s.tapReveal {
                    Toggle(isOn: $s.splitLine) {
                        RowLabel(s.tr("Vis skillestreg", "Show divider"), icon: "minus", color: .gray,
                                 detail: s.tr("Svag grå streg i siderne, der viser midten", "Faint grey marks showing the middle"))
                    }
                    .accessibilityIdentifier("splitLineToggle")
                }
            }
            if s.mode == .hidden {
                PhotosPicker(selection: $photo, matching: .images) {
                    RowLabel(s.hasBackground ? s.tr("Skift baggrundsbillede", "Change background image")
                                             : s.tr("Vælg baggrundsbillede", "Choose background image"),
                             icon: "photo.fill", color: .blue,
                             detail: s.tr("Fx et skærmbillede af din hjemmeskærm", "E.g. a screenshot of your home screen"))
                }
                .accessibilityIdentifier("backgroundPicker")
                if s.hasBackground {
                    Button(role: .destructive) {
                        BackgroundStore.clear()
                        s.hasBackground = false
                    } label: {
                        Label(s.tr("Fjern billede (brug sort)", "Remove image (use black)"), systemImage: "trash")
                    }
                }
                if photoError {
                    Text(s.tr("Billedet kunne ikke indlæses.", "Could not load the image.")).font(.caption).foregroundStyle(.red)
                }
            }
        } header: {
            Text(s.tr("Visning", "Display"))
        } footer: {
            Text(s.mode == .hidden
                 ? s.tr("Hemmelig: skærmen ser sort ud (eller viser dit billede). Tryk for at starte og stoppe – du får kun vibrationen.",
                        "Secret: the screen looks black (or shows your image). Tap to start and stop – you only get the vibration.")
                 : s.tapReveal
                 ? s.tr("Normal: tryk på startskærmen. Rør så øverst for Sandt eller nederst for Falsk (volumenknapperne virker stadig).",
                        "Normal: tap the start screen. Then touch the top for True or the bottom for False (volume buttons still work).")
                 : s.tr("Normal: tryk på startskærmen. Volumen op = Sandt, volumen ned = Falsk.",
                        "Normal: tap the start screen. Volume up = True, volume down = False."))
        }
    }

    // MARK: 6. Udseende
    private var looksSection: some View {
        Section {
            HStack {
                RowLabel(s.tr("Sprog", "Language"), icon: "globe", color: .blue)
                Spacer(minLength: 16)
                Picker(s.tr("Sprog", "Language"), selection: $s.language) {
                    Text("English").tag(AppLanguage.en)
                    Text("Dansk").tag(AppLanguage.da)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 170)
                .accessibilityIdentifier("languagePicker")
            }

            VStack(alignment: .leading, spacing: 10) {
                RowLabel(s.tr("Skrifttype", "Font"), icon: "textformat", color: .pink)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                    ForEach(AppFont.allCases) { f in
                        Button { s.font = f } label: {
                            VStack(spacing: 4) {
                                Text("Aa").font(f.font(22)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                                Text(f.displayName).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.18)))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(s.font == f ? Color.sandt : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 10) {
                RowLabel(s.tr("App-ikon", "App icon"), icon: "app.fill", color: .indigo)
                HStack(spacing: 12) {
                    ForEach(AppIconChoice.allCases) { c in
                        Button {
                            let previous = icon
                            icon = c
                            c.apply { ok in if !ok { icon = previous; iconError = true } }
                        } label: {
                            VStack(spacing: 6) {
                                Image(c.preview)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(icon == c ? Color.sandt : .clear, lineWidth: 3))
                                Text(c.label(s)).font(.caption2).foregroundStyle(icon == c ? .primary : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if iconError {
                    Text(s.tr("Ikonet kunne ikke skiftes.", "Could not change the icon.")).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text(s.tr("Udseende", "Appearance"))
        }
    }

    // MARK: 7. Avanceret
    private var advancedSection: some View {
        Section {
            DisclosureGroup(isExpanded: $showAdvanced) {
                Stepper(s.tr("Målinger i træk: \(s.consecutive)", "Readings in a row: \(s.consecutive)"), value: $s.consecutive, in: 1...20)
                Picker(s.tr("Måling", "Measuring"), selection: $s.sensorMode) {
                    Text(s.tr("Auto (tåler drejning)", "Auto (ignores turning)")).tag(SensorMode.auto)
                    Text(s.tr("Rå (hold roligt)", "Raw (hold still)")).tag(SensorMode.raw)
                }
                HStack { Text(s.tr("Kalibrering", "Calibration")); Spacer(); Text(accuracyText).foregroundStyle(.secondary) }
                HStack { Text(s.tr("Målinger/s", "Readings/s")); Spacer(); Text("\(engine.sensor.rate)").foregroundStyle(.secondary) }
                Button(s.tr("Nulstil måling", "Reset reading")) { engine.resetLive() }
                VStack(alignment: .leading, spacing: 6) {
                    Text(s.tr("Seneste gæt", "Recent guesses")).font(.subheadline.bold())
                    if engine.log.isEmpty { Text("—").foregroundStyle(.secondary) }
                    ForEach(engine.log) { e in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.time, style: .time).font(.caption2).foregroundStyle(.secondary)
                            Text(e.text).font(.caption)
                        }
                    }
                }
            } label: {
                RowLabel(s.tr("Avanceret", "Advanced"), icon: "gearshape.fill", color: .gray)
            }
        } footer: {
            Text(s.tr("Kun til fejlsøgning – behøver normalt ikke ændres.", "For troubleshooting only – normally no need to change."))
        }
    }

    private var accuracyText: String {
        switch engine.sensor.accuracyLevel {
        case 0: return s.tr("lav", "low")
        case 1: return s.tr("middel", "medium")
        case 2: return s.tr("høj", "high")
        default: return "—"
        }
    }
}

// MARK: - Små byggeklodser

/// Farvet ikon i en afrundet firkant, som i iPhones Indstillinger.
struct RowIcon: View {
    let symbol: String
    let color: Color
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(color))
    }
}

struct RowLabel: View {
    let title: String
    let icon: String
    let color: Color
    var detail: String? = nil
    init(_ title: String, icon: String, color: Color, detail: String? = nil) {
        self.title = title; self.icon = icon; self.color = color; self.detail = detail
    }
    var body: some View {
        HStack(spacing: 12) {
            RowIcon(symbol: icon, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundStyle(.primary)
                if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

/// Skyder med titel og værdi til højre.
struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let text: String
    let sliderID: String
    let valueID: String
    var minIcon: String? = nil
    var maxIcon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(text).monospacedDigit().foregroundStyle(.secondary).accessibilityIdentifier(valueID)
            }
            HStack(spacing: 10) {
                if let minIcon { Image(systemName: minIcon).font(.caption).foregroundStyle(.secondary) }
                Slider(value: $value, in: range, step: step).accessibilityIdentifier(sliderID)
                if let maxIcon { Image(systemName: maxIcon).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .padding(.vertical, 2)
    }
}

/// Lille afrundet knap (afspil lyd, test vibration).
struct PillButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(Capsule().fill(color))
        }
        .buttonStyle(.borderless)
    }
}

/// Mini-udgave af resultatskærmen.
struct ResultPreview: View {
    let text: String
    let color: Color
    let font: AppFont
    var body: some View {
        Text(text)
            .font(font.font(20))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.4)
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 70)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color))
    }
}

/// Forslag til tekster: to små farvede felter.
struct PresetChip: View {
    let t: String
    let f: String
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                part(t, .sandt)
                part(f, .falsk)
            }
            .padding(4)
            .background(Capsule().fill(Color(white: 0.16)))
            .overlay(Capsule().stroke(selected ? Color.white : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
    private func part(_ text: String, _ c: Color) -> some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(c))
    }
}

/// Status + bjælke: udslag nu, top-markør og hvid streg = følsomhed (opdateres alene, højst 10 gange i sekundet).
struct LiveMeter: View {
    @EnvironmentObject var s: AppSettings
    @ObservedObject var readout: LiveReadout
    let threshold: Double
    let hardware: Bool

    var body: some View {
        let value = readout.value, peak = readout.peak, live = readout.live
        let scale = max(threshold * 2, 10)
        let over = live && value >= threshold
        let status: (String, Color) = !hardware ? (s.tr("Ingen sensor", "No sensor"), .red)
            : !live ? (s.tr("Venter på sensor …", "Waiting for sensor …"), .orange)
            : over ? (s.tr("Magnet fundet", "Magnet found"), .falsk)
            : (s.tr("Ingen magnet", "No magnet"), .green)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(status.1).frame(width: 10, height: 10)
                Text(status.0).font(.headline)
                Spacer()
                Text(live ? String(format: "%.0f µT", value) : "—")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.22))
                    Capsule().fill(over ? Color.falsk : Color.sandt)
                        .frame(width: w * min(1, value / scale))
                    Rectangle().fill(Color.white.opacity(0.45)).frame(width: 2)
                        .offset(x: w * min(1, peak / scale) - 1)
                    RoundedRectangle(cornerRadius: 1.5).fill(Color.white).frame(width: 3, height: 22)
                        .offset(x: w * min(1, threshold / scale) - 1.5)
                }
            }
            .frame(height: 12)
            .allowsHitTesting(false)
        }
        .padding(.vertical, 6)
    }
}

/// "Lær min magnet": måler uden og med magnet og indstiller følsomheden selv.
struct LearnView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var s: AppSettings

    var body: some View {
        Form {
            Section {
                Text(s.tr("Appen lærer forskellen på \"ingen magnet\" og \"magnet\". Det virker med alle magnetiske ting – mønter, ringe, kort osv.",
                          "The app learns the difference between \"no magnet\" and \"magnet\". Works with any magnetic object – coins, rings, cards etc."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
            }

            step(1,
                 title: s.tr("Uden magnet", "Without magnet"),
                 text: s.tr("Læg magneten væk. Tryk Start, og bevæg telefonen roligt rundt i 3 sekunder.",
                            "Put the magnet away. Tap Start and move the phone around gently for 3 seconds."),
                 running: engine.learnRunning && engine.learnStep == .noise,
                 done: engine.learnNoise != nil,
                 enabled: !engine.learnRunning) { engine.learn(.noise) }

            step(2,
                 title: s.tr("Med magnet", "With magnet"),
                 text: s.tr("Hold magneten i en lukket hånd. Tryk Start, og før toppen af telefonen hen over hånden i 3 sekunder.",
                            "Hold the magnet in a closed hand. Tap Start and move the top of the phone over the hand for 3 seconds."),
                 running: engine.learnRunning && engine.learnStep == .coin,
                 done: engine.learnCoin != nil && engine.learnOK == true,
                 enabled: !engine.learnRunning && engine.learnNoise != nil) { engine.learn(.coin) }

            if let m = engine.learnMessage {
                Section {
                    Label(m, systemImage: engine.learnOK == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(engine.learnOK == true ? Color.green : Color.orange)
                }
            }
            if engine.learnNoise != nil {
                Section {
                    Button(s.tr("Start forfra", "Start over")) { engine.resetLearn() }
                }
            }
        }
        .navigationTitle(s.tr("Lær min magnet", "Learn my magnet"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { engine.resetLearn() }
    }

    private func step(_ n: Int, title: String, text: String, running: Bool, done: Bool, enabled: Bool,
                      action: @escaping () -> Void) -> some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(done ? Color.green : (enabled || running ? Color.sandt : Color(white: 0.3)))
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold))
                    } else {
                        Text("\(n)").font(.system(size: 15, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(text).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            Button(action: action) {
                HStack {
                    if running { ProgressView().tint(.white) }
                    Text(running ? s.tr("Måler …", "Measuring …")
                                 : done ? s.tr("Mål igen", "Measure again") : "Start")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!enabled)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        }
    }
}
