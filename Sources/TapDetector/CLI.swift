import Foundation

public struct Options {
    public var debugMode: Bool = false
    public var sensitivityThreshold: Double? = nil
    public var sensitivityMultiplier: Double = 5.0
    public var cooldownMs: Int = 200
    public var soundMode: String = "random"
    public var soundsDirectory: URL = URL(fileURLWithPath: "sounds")
    public var runCalibration: Bool = true
    public var calibrationDuration: Double = 2.0
    public var listSounds: Bool = false
    public var testAudio: Bool = false
    public var showHelp: Bool = false

    public static func parse(args: [String] = CommandLine.arguments) -> Options {
        var opts = Options()
        var i = 1

        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-d", "--debug":
                opts.debugMode = true

            case "--no-debug":
                opts.debugMode = false

            case "-s", "--sensitivity", "--threshold":
                if i + 1 < args.count, let val = Double(args[i + 1]) {
                    opts.sensitivityThreshold = val
                    i += 1
                }

            case "--multiplier":
                if i + 1 < args.count, let val = Double(args[i + 1]) {
                    opts.sensitivityMultiplier = val
                    i += 1
                }

            case "-c", "--cooldown":
                if i + 1 < args.count, let val = Int(args[i + 1]) {
                    opts.cooldownMs = val
                    i += 1
                }

            case "-m", "--mode":
                if i + 1 < args.count {
                    opts.soundMode = args[i + 1].lowercased()
                    i += 1
                }

            case "--sounds-dir":
                if i + 1 < args.count {
                    opts.soundsDirectory = URL(fileURLWithPath: args[i + 1])
                    i += 1
                }

            case "--no-calibrate":
                opts.runCalibration = false

            case "--calibrate-time":
                if i + 1 < args.count, let val = Double(args[i + 1]) {
                    opts.calibrationDuration = val
                    i += 1
                }

            case "--list-sounds":
                opts.listSounds = true

            case "--test-audio":
                opts.testAudio = true

            case "-h", "--help":
                opts.showHelp = true

            default:
                print("Unknown argument: \(arg)")
                opts.showHelp = true
            }
            i += 1
        }
        return opts
    }

    public static func printHelp() {
        print("""
        ⚡ MACBOOK CHASSIS TAP DETECTOR ⚡
        Turn your MacBook into a tap-to-bonk sound machine using native hardware accelerometer sensing.

        USAGE:
            tap-detector [options]

        OPTIONS:
            -d, --debug                Enable rich ANSI live terminal dashboard
            -s, --threshold <g>        Detection threshold in g (e.g. 0.20). Overrides auto-calibration.
            --multiplier <val>         Sensitivity multiplier for auto-calibration (default: 5.0)
            -c, --cooldown <ms>        Debounce cooldown in milliseconds (default: 200 ms)
            -m, --mode <name>          Sound mode: random, bonk, meme, system (default: random)
            --sounds-dir <path>        Path to custom sounds folder (default: ./sounds)
            --no-calibrate             Skip the 2-second resting calibration
            --calibrate-time <sec>     Calibration duration in seconds (default: 2.0s)
            --list-sounds              List discovered sounds in catalog and exit
            --test-audio               Test speaker playback with loaded sounds and exit
            -h, --help                 Show this help message

        EXAMPLES:
            swift run tap-detector
            swift run tap-detector --debug
            swift run tap-detector --debug --mode bonk --cooldown 150
            swift run tap-detector --threshold 0.18
        """)
    }
}
