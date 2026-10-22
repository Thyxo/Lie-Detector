import SwiftUI

extension Color {
    static let sandt = Color(red: 59 / 255, green: 196 / 255, blue: 202 / 255)
    static let falsk = Color(red: 1, green: 0, blue: 0)
}

struct RootView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var phase

    @State private var secretTaps: [Date] = []

    var body: some View {
        ZStack {
            Group {
                if settings.mode == .hidden {
                    HiddenScreen()
                } else {
                    switch engine.screen {
                    case .start: StartScreen()
                    case .thinking: ThinkingScreen()
                    case .result(let v): ResultScreen(verdict: v)
                    }
                }
            }
            .ignoresSafeArea()

            // Skjult volumenvisning (skjuler iOS' lydstyrke-boble)
            HiddenVolumeView(view: engine.volume.volumeView)
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)

            // Hemmelig zone: 5 hurtige tryk i øverste højre hjørne
            VStack {
                HStack {
                    Spacer()
                    Color.clear
                        .frame(width: 90, height: 90)
                        .contentShape(Rectangle())
                        .onTapGesture { secretTap() }
                }
                Spacer()
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $engine.panelOpen) {
            SecretPanel()
                .environmentObject(engine)
                .environmentObject(settings)
        }
        .onChange(of: phase) { _, p in if p == .active { engine.becameActive() } }
        .onAppear { engine.becameActive() }
    }

    private func secretTap() {
        let now = Date()
        secretTaps = secretTaps.filter { now.timeIntervalSince($0) < 2.5 } + [now]
        if secretTaps.count >= 5 {
            secretTaps = []
            engine.panelOpen = true
        }
    }
}

/// Stor tekst i den valgte skrift. Skaleres ned hvis ordet er for bredt.
struct BigWord: View {
    @EnvironmentObject var settings: AppSettings
    let text: String
    var size: Double = 76

    var body: some View {
        Text(text)
            .font(settings.font.font(size))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .padding(.horizontal, 24)
    }
}

struct StartScreen: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            Color.black
            BigWord(text: settings.tr("Sandt eller falsk?", "True or false?"), size: 30)
                .opacity(0.9)

            // Diskret prik: venstre = Sandt klar, højre = Falsk klar
            if settings.dot, let a = engine.armed {
                VStack {
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 5, height: 5)
                        .offset(x: a == .sandt ? -8 : 8)
                        .padding(.top, 70)
                    Spacer()
                }
            }

            // Panik: hold nederste venstre hjørne i ¾ s
            VStack {
                Spacer()
                HStack {
                    Color.clear
                        .frame(width: 100, height: 100)
                        .contentShape(Rectangle())
                        .onTapGesture { engine.tapStart() }
                        .onLongPressGesture(minimumDuration: 0.75) { engine.panic() }
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { engine.tapStart() }
    }
}

struct ThinkingScreen: View {
    @EnvironmentObject var settings: AppSettings
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 28) {
                BigWord(text: settings.tr("Tænker", "Thinking"), size: 58)
                Circle()
                    .fill(Color.sandt)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulse ? 1.0 : 0.5)
                    .opacity(pulse ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulse)
            }
        }
        .onAppear { pulse = true }
    }
}

struct ResultScreen: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var settings: AppSettings
    let verdict: Verdict
    @State private var shown = false

    var body: some View {
        ZStack {
            (verdict == .sandt ? Color.sandt : Color.falsk)
            BigWord(text: settings.word(verdict), size: 80)
                .scaleEffect(shown ? 1 : 0.6)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: shown)
        }
        .contentShape(Rectangle())
        .onTapGesture { engine.tapResult() }
        .onAppear { shown = true }
    }
}

/// Hemmelig tilstand: sort skærm eller eget billede. Tryk = scan, svaret vibreres.
struct HiddenScreen: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var settings: AppSettings
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if settings.hasBackground, let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .contentShape(Rectangle())
        .onTapGesture { engine.tapHidden() }
        .onAppear { image = BackgroundStore.load() }
        .onChange(of: settings.backgroundVersion) { _, _ in image = BackgroundStore.load() }
    }
}
