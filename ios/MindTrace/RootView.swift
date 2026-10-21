import SwiftUI

extension Color {
    static let sandt = Color(red: 59 / 255, green: 196 / 255, blue: 202 / 255)
    static let falsk = Color(red: 1, green: 0, blue: 0)
}

private let fontName = "GillSans"

struct RootView: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var phase

    @State private var secretTaps: [Date] = []

    var body: some View {
        ZStack {
            screen
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

    @ViewBuilder private var screen: some View {
        switch engine.screen {
        case .start:
            StartScreen()
        case .thinking:
            ThinkingScreen()
        case .result(let v):
            ResultScreen(verdict: v)
        }
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

struct StartScreen: View {
    @EnvironmentObject var engine: Engine
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ZStack {
            Color.black
            Text("Sandt eller falsk?")
                .font(.custom(fontName, size: 30))
                .foregroundStyle(.white.opacity(0.85))

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
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 28) {
                Text("Tænker")
                    .font(.custom(fontName, size: 64))
                    .foregroundStyle(.white)
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
    let verdict: Verdict

    var body: some View {
        ZStack {
            (verdict == .sandt ? Color.sandt : Color.falsk)
            Text(verdict.label)
                .font(.custom(fontName, size: 72))
                .foregroundStyle(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture { engine.tapResult() }
    }
}
