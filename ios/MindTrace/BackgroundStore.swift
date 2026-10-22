import UIKit

/// Billede til hemmelig tilstand (fx skærmbillede af egen hjemmeskærm). Gemmes kun på telefonen.
enum BackgroundStore {
    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("hidden-background.jpg")
    }

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func save(_ data: Data) -> Bool {
        guard let img = UIImage(data: data), let jpg = img.jpegData(compressionQuality: 0.9) else { return false }
        return (try? jpg.write(to: url, options: .atomic)) != nil
    }

    static func clear() { try? FileManager.default.removeItem(at: url) }
}
