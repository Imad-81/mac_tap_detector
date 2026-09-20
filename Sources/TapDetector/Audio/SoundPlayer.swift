import Foundation
import AVFoundation
import AppKit

public final class SoundPlayer: NSObject, AVAudioPlayerDelegate {
    private let audioQueue = DispatchQueue(label: "com.tapdetector.audio", qos: .userInteractive)
    private var activePlayers: [AVAudioPlayer] = []
    private let lock = NSLock()

    public override init() {
        super.init()
    }

    /// Plays the specified sound asynchronously without blocking the sensor thread
    public func play(sound: SoundItem, volume: Float = 1.0) {
        audioQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: sound.url)
                player.delegate = self
                player.volume = volume
                player.prepareToPlay()
                player.play()

                self.lock.lock()
                self.activePlayers.append(player)
                self.lock.unlock()
            } catch {
                // Fallback to NSSound
                if let nsSound = NSSound(contentsOf: sound.url, byReference: true) {
                    nsSound.play()
                } else {
                    NSSound.beep()
                }
            }
        }
    }

    /// Plays a random sound from the library and returns the selected sound name
    @discardableResult
    public func playRandom(from library: SoundLibrary) -> String {
        if let sound = library.getRandomSound() {
            play(sound: sound)
            return sound.name
        } else {
            // System beep fallback
            audioQueue.async {
                NSSound.beep()
            }
            return "system_beep"
        }
    }

    // MARK: - AVAudioPlayerDelegate
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        lock.lock()
        activePlayers.removeAll { $0 === player }
        lock.unlock()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        lock.lock()
        activePlayers.removeAll { $0 === player }
        lock.unlock()
    }
}
