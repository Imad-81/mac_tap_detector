import Foundation
import CoreFoundation

// Ensure standard output is unbuffered for immediate terminal rendering
setbuf(stdout, nil)

// 1. Parse Arguments
let options = Options.parse()

if options.showHelp {
    Options.printHelp()
    exit(0)
}

// 2. Sound Library
let soundLibrary = SoundLibrary(directory: options.soundsDirectory, mode: options.soundMode)

if options.listSounds {
    print("Found \(soundLibrary.sounds.count) available sounds (Mode: '\(soundLibrary.requestedMode)'):")
    for (i, sound) in soundLibrary.sounds.enumerated() {
        print(String(format: " %2d. %@ [%@] -> %@", i + 1, sound.name, sound.category, sound.url.path))
    }
    exit(0)
}

let soundPlayer = SoundPlayer()

if options.testAudio {
    print("Testing audio playback with \(soundLibrary.sounds.count) sounds...")
    for sound in soundLibrary.sounds.prefix(5) {
        print("Playing: \(sound.name)...")
        soundPlayer.play(sound: sound)
        Thread.sleep(forTimeInterval: 0.6)
    }
    print("Audio test completed!")
    exit(0)
}

// 3. Sensor & Signal Engine Setup
let accelService = AccelerometerService()
let cooldownSeconds = Double(options.cooldownMs) / 1000.0
let tapEngine = TapDetectorEngine(
    threshold: options.sensitivityThreshold ?? 0.22,
    cooldownSeconds: cooldownSeconds
)

let dashboard = Dashboard()
dashboard.threshold = tapEngine.threshold
dashboard.cooldownMs = options.cooldownMs
dashboard.modeName = options.soundMode
dashboard.soundCount = soundLibrary.sounds.count

// Clean terminal restoration on SIGINT
let isDebug = options.debugMode
let sigSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigSource.setEventHandler {
    if isDebug {
        dashboard.restoreTerminal()
    }
    accelService.stop()
    print("\n👋 Tap Detector stopped. Total taps detected: \(tapEngine.totalTaps)")
    exit(0)
}
signal(SIGINT, SIG_IGN) // Handle via DispatchSource
sigSource.resume()

// 4. Calibration state
var isCalibrating = options.runCalibration && (options.sensitivityThreshold == nil)
let calibrator = SensorCalibrator(
    duration: options.calibrationDuration,
    multiplier: options.sensitivityMultiplier
)

var lastProgressPct = -1
if isCalibrating {
    print("⏳ Calibrating resting noise for \(options.calibrationDuration)s... (Keep MacBook still)")
} else {
    print("⚡ Tap Detector armed! Threshold: \(String(format: "%.3fg", tapEngine.threshold)), Cooldown: \(options.cooldownMs)ms")
    print("👉 Hit or tap the MacBook chassis to bonk. Press Ctrl+C to quit.\n")
    if isDebug {
        dashboard.setupTerminal()
    }
}

// 5. Connect Sensor Callback
do {
    try accelService.start { sample in
        if isCalibrating {
            calibrator.addSample(sample)
            let pct = Int(calibrator.progress * 100)
            if !isDebug && pct != lastProgressPct && pct % 20 == 0 {
                lastProgressPct = pct
                print("   Measuring noise: \(pct)%...")
            }

            if calibrator.isComplete {
                let result = calibrator.finish()
                isCalibrating = false
                tapEngine.updateThreshold(result.recommendedThreshold)
                dashboard.threshold = result.recommendedThreshold

                print("\n✅ " + result.summary)
                print("⚡ Tap Detector armed! Ready for bonks!\n")

                if isDebug {
                    Thread.sleep(forTimeInterval: 0.8) // Let user read summary
                    dashboard.setupTerminal()
                }
            }
            return
        }

        let (signal, tapEvent) = tapEngine.processSample(sample)

        if let tap = tapEvent {
            let soundName = soundPlayer.playRandom(from: soundLibrary)

            if isDebug {
                dashboard.recordTap(event: tap, soundName: soundName)
            } else {
                let timestampStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                print(String(format: "[%@] 💥 TAP #%d DETECTED! Force: %+.3fg (jerk: %.3fg) -> 🔊 Playing: %@",
                             timestampStr, tap.tapIndex, tap.peakMagnitude, tap.jerk, soundName))
            }
        }

        if isDebug {
            dashboard.updateSignal(sample: sample, signal: signal, currentHz: accelService.currentHz)
        }
    }
} catch {
    if isDebug { dashboard.restoreTerminal() }
    print("❌ Error starting accelerometer service: \(error.localizedDescription)")
    exit(1)
}

// 6. Run CoreFoundation RunLoop
CFRunLoopRun()

