import AVFoundation

/// Afspiller sandt/falsk-lydene (mp3 i appen).
final class Sounds {
    private var players: [Verdict: AVAudioPlayer] = [:]

    init() {
        for (v, name) in [(Verdict.sandt, "true"), (Verdict.falsk, "false")] {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.prepareToPlay()
                players[v] = p
            }
        }
    }

    /// `volume` 0...1 (oven i telefonens egen lydstyrke).
    func play(_ v: Verdict, volume: Double = 1) {
        guard volume > 0, let p = players[v] else { return }
        for other in players.values where other.isPlaying { other.stop() }
        p.currentTime = 0
        p.volume = Float(min(1, max(0, volume)))
        p.play()
    }
}
