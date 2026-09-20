import Foundation
import AppKit

public struct SoundItem: CustomStringConvertible {
    public let name: String
    public let url: URL
    public let category: String

    public var description: String {
        return "\(name) [\(category)]"
    }
}

public final class SoundLibrary {
    public static let targetSoundFileName = "ma-ka-bhosda-aag.mp3"

    public private(set) var sounds: [SoundItem] = []
    public let searchDirectory: URL
    public let requestedMode: String

    public init(directory: URL, mode: String = "random") {
        self.searchDirectory = directory
        self.requestedMode = mode.lowercased()
        reload()
    }

    public func reload() {
        sounds.removeAll()

        let fm = FileManager.default
        let targetName = SoundLibrary.targetSoundFileName
        var targetURL: URL?

        // 1. Check directly in searchDirectory
        let directInSearch = searchDirectory.appendingPathComponent(targetName)
        if fm.fileExists(atPath: directInSearch.path) {
            targetURL = directInSearch
        }

        // 2. Check standard candidate paths
        if targetURL == nil {
            let candidates = [
                URL(fileURLWithPath: "sounds").appendingPathComponent(targetName),
                URL(fileURLWithPath: targetName),
                URL(fileURLWithPath: "/Users/imadmac/projects/tap_detector/sounds").appendingPathComponent(targetName)
            ]
            for candidate in candidates {
                if fm.fileExists(atPath: candidate.path) {
                    targetURL = candidate
                    break
                }
            }
        }

        // 3. Recursive search inside searchDirectory if still not found
        if targetURL == nil, let enumerator = fm.enumerator(at: searchDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.lowercased() == targetName.lowercased() {
                    targetURL = fileURL
                    break
                }
            }
        }

        if let validURL = targetURL {
            sounds = [SoundItem(
                name: validURL.lastPathComponent,
                url: validURL,
                category: "exclusive"
            )]
        } else {
            print("⚠️ Warning: Exclusive audio file '\(targetName)' was not found in \(searchDirectory.path).")
        }
    }

    public func getRandomSound() -> SoundItem? {
        return sounds.first
    }
}
