import UIKit

final class AvatarCache {

    static let shared = AvatarCache()
    private init() {}

    private func avatarURL(for umpireID: String) -> URL {
        let cacheDir = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return cacheDir.appendingPathComponent("avatar_\(umpireID).jpg")
    }

    func loadAvatar(
        umpireID: String,
        remoteURL: String?
    ) async -> UIImage? {

        let localURL = avatarURL(for: umpireID)

        // Try disk first
        if let data = try? Data(contentsOf: localURL),
           let image = UIImage(data: data) {
            return image
        }

        // Download if needed
        guard let remoteURL,
              let url = URL(string: remoteURL) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: localURL, options: .atomic)
            return UIImage(data: data)
        } catch {
            print("AvatarCache error:", error)
            return nil
        }
    }

    func saveAvatar(
        umpireID: String,
        data: Data
    ) {
        let localURL = avatarURL(for: umpireID)
        try? data.write(to: localURL, options: .atomic)
    }

    func clearAvatar(umpireID: String) {
        let localURL = avatarURL(for: umpireID)
        try? FileManager.default.removeItem(at: localURL)
    }
}
