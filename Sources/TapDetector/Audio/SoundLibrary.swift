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

        // If directory doesn't exist or is empty, create starter sounds
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: searchDirectory.path, isDirectory: &isDir) || !isDir.boolValue {
            try? fm.createDirectory(at: searchDirectory, withIntermediateDirectories: true)
        }

        let existingFiles = (try? fm.contentsOfDirectory(atPath: searchDirectory.path)) ?? []
        let audioFiles = existingFiles.filter { isAudioExtension($0) }

        if audioFiles.isEmpty {
            // Generate starter sound set
            WaveSynthesizer.ensureStarterSounds(in: searchDirectory)
        }

        // Scan the project directory
        scanDirectory(searchDirectory)

        // If in "system" mode or if directory had no audio, load macOS system sounds
        if requestedMode == "system" || sounds.isEmpty {
            loadSystemSounds()
        }

        // Filter by mode if specific mode requested
        filterByMode()
    }

    private func isAudioExtension(_ filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["wav", "mp3", "aiff", "aif", "m4a", "caf", "aac"].contains(ext)
    }

    private func scanDirectory(_ dir: URL) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return }

        for case let fileURL as URL in enumerator {
            if isAudioExtension(fileURL.lastPathComponent) {
                let parentDirName = fileURL.deletingLastPathComponent().lastPathComponent.lowercased()
                let category: String
                if parentDirName != searchDirectory.lastPathComponent.lowercased() {
                    category = parentDirName
                } else {
                    category = categorizeSound(filename: fileURL.lastPathComponent)
                }

                sounds.append(SoundItem(
                    name: fileURL.lastPathComponent,
                    url: fileURL,
                    category: category
                ))
            }
        }
    }

    private func categorizeSound(filename: String) -> String {
        let lower = filename.lowercased()
        if lower.contains("bonk") || lower.contains("thud") || lower.contains("metal") || lower.contains("pipe") || lower.contains("hit") {
            return "bonk"
        }
        if lower.contains("meme") || lower.contains("vine") || lower.contains("bruh") || lower.contains("boing") {
            return "meme"
        }
        return "general"
    }

    private func loadSystemSounds() {
        let systemSoundsDir = URL(fileURLWithPath: "/System/Library/Sounds")
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(atPath: systemSoundsDir.path) {
            for f in files where isAudioExtension(f) {
                let url = systemSoundsDir.appendingPathComponent(f)
                sounds.append(SoundItem(
                    name: f,
                    url: url,
                    category: "system"
                ))
            }
        }
    }

    private func filterByMode() {
        guard !sounds.isEmpty else { return }

        switch requestedMode {
        case "bonk":
            let matched = sounds.filter { $0.category == "bonk" || $0.name.lowercased().contains("bonk") }
            if !matched.isEmpty { self.sounds = matched }
        case "meme":
            let matched = sounds.filter { $0.category == "meme" || $0.name.lowercased().contains("boing") || $0.name.lowercased().contains("meme") }
            if !matched.isEmpty { self.sounds = matched }
        case "system":
            let matched = sounds.filter { $0.category == "system" }
            if !matched.isEmpty { self.sounds = matched }
        case "random":
            fallthrough
        default:
            break
        }
    }

    public func getRandomSound() -> SoundItem? {
        return sounds.randomElement()
    }
}
