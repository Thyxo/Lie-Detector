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

    func play(_ v: Verdict) {
        guard let p = players[v] else { return }
        p.currentTime = 0
        p.volume = 1
        p.play()
    }
}
