import Foundation

public final class Dashboard {
    public var sensorConnected = true
    public var sensorModel = "Apple SPU (Bosch BMI286)"
    public var currentHz: Double = 0.0
    public var threshold: Double = 0.22
    public var cooldownMs: Int = 200
    public var modeName: String = "random"
    public var soundCount: Int = 0

    public var currentX: Double = 0.0
    public var currentY: Double = 0.0
    public var currentZ: Double = -1.0
    public var currentDynamic: Double = 0.0

    public var statusText: String = "WAITING FOR BONK"
    public var lastEventText: String = "None"
    public var totalTaps: Int = 0

    private var lastRenderTime: Double = 0.0
    private let targetFps: Double = 25.0
    private var isTapFlashing: Bool = false
    private var tapFlashEndTime: Double = 0.0

    public init() {}

    public func setupTerminal() {
        // Hide cursor and clear screen
        print("\u{001B}[?25l\u{001B}[2J\u{001B}[H", terminator: "")
        fflush(stdout)
    }

    public func restoreTerminal() {
        // Show cursor
        print("\u{001B}[?25h")
        fflush(stdout)
    }

    public func recordTap(event: TapEvent, soundName: String) {
        totalTaps = event.tapIndex
        statusText = "💥 TAP DETECTED! 💥"
        lastEventText = String(format: "💥 #%d (%.2fg) -> %@", event.tapIndex, event.peakMagnitude, soundName)
        isTapFlashing = true
        tapFlashEndTime = CFAbsoluteTimeGetCurrent() + 0.45 // Flash for 450ms
        render(force: true)
    }

    public func updateSignal(sample: AccelSample, signal: ProcessedSignal, currentHz: Double) {
        self.currentX = sample.x
        self.currentY = sample.y
        self.currentZ = sample.z
        self.currentDynamic = signal.dynamicMagnitude
        self.currentHz = currentHz

        let now = CFAbsoluteTimeGetCurrent()
        if isTapFlashing && now >= tapFlashEndTime {
            isTapFlashing = false
            statusText = "WAITING FOR BONK"
        }

        let interval = 1.0 / targetFps
        if now - lastRenderTime >= interval {
            render(force: false)
            lastRenderTime = now
        }
    }

    private func render(force: Bool) {
        var out = ""
        // Move cursor to home (top-left) without clearing whole screen to prevent flicker
        out += "\u{001B}[H"

        let width = 50
        func pad(_ s: String, _ len: Int) -> String {
            if s.count >= len { return String(s.prefix(len)) }
            return s + String(repeating: " ", count: len - s.count)
        }

        func makeBar(value: Double, max: Double, barWidth: Int = 16) -> String {
            let ratio = Swift.max(0.0, Swift.min(1.0, value / max))
            let filled = Int(round(ratio * Double(barWidth)))
            let unfilled = barWidth - filled
            return String(repeating: "█", count: filled) + String(repeating: "░", count: unfilled)
        }

        // Colors
        let cyan = "\u{001B}[1;36m"
        let green = "\u{001B}[1;32m"
        let yellow = "\u{001B}[1;33m"
        let red = "\u{001B}[1;31m"
        let magenta = "\u{001B}[1;35m"
        let reset = "\u{001B}[0m"
        let bold = "\u{001B}[1m"

        let statusColor = isTapFlashing ? red : (sensorConnected ? green : yellow)

        out += "╭" + String(repeating: "─", count: width) + "╮\n"
        out += "│" + cyan + bold + pad("         ⚡ MACBOOK CHASSIS TAP DETECTOR ⚡", width) + reset + "│\n"
        out += "├" + String(repeating: "─", count: width) + "┤\n"

        let sensorLine = String(format: " Sensor:      %@CONNECTED%@ (%@)", green, reset, sensorModel)
        out += "│" + pad(sensorLine, width + green.count + reset.count) + "│\n"

        let samplingLine = String(format: " Sampling:    %.0f Hz", currentHz)
        out += "│" + pad(samplingLine, width) + "│\n"

        let sensBar = makeBar(value: threshold, max: 0.8, barWidth: 10)
        let sensLine = String(format: " Threshold:   [%@] %.2fg", sensBar, threshold)
        out += "│" + pad(sensLine, width) + "│\n"

        let cooldownLine = String(format: " Cooldown:    %d ms", cooldownMs)
        out += "│" + pad(cooldownLine, width) + "│\n"

        let modeLine = String(format: " Mode:        %@ (%d sounds ready)", modeName, soundCount)
        out += "│" + pad(modeLine, width) + "│\n"

        out += "├" + String(repeating: "─", count: width) + "┤\n"

        let xLine = String(format: " X:  %+6.3f g", currentX)
        let yLine = String(format: " Y:  %+6.3f g", currentY)
        let zLine = String(format: " Z:  %+6.3f g", currentZ)
        out += "│" + pad(xLine, width) + "│\n"
        out += "│" + pad(yLine, width) + "│\n"
        out += "│" + pad(zLine, width) + "│\n"

        let dynBar = makeBar(value: currentDynamic, max: Swift.max(0.5, threshold * 2.0), barWidth: 14)
        let dynColor = currentDynamic >= threshold ? red : yellow
        let dynLine = String(format: " Dynamic:     [%@%@%@] %.3fg", dynColor, dynBar, reset, currentDynamic)
        out += "│" + pad(dynLine, width + dynColor.count + reset.count) + "│\n"

        out += "├" + String(repeating: "─", count: width) + "┤\n"

        let statusDisplay = String(format: " Status:      %@%@%@ ", statusColor, statusText, reset)
        out += "│" + pad(statusDisplay, width + statusColor.count + reset.count) + "│\n"

        let eventLine = String(format: " Last Event:  %@", lastEventText)
        out += "│" + pad(eventLine, width) + "│\n"

        let tapsLine = String(format: " Total Taps:  %@%d%@", magenta + bold, totalTaps, reset)
        out += "│" + pad(tapsLine, width + magenta.count + bold.count + reset.count) + "│\n"

        out += "╰" + String(repeating: "─", count: width) + "╯\n"
        out += "\u{001B}[2m(Hit the laptop chassis to bonk. Press Ctrl+C to exit)\u{001B}[0m\n"

        print(out, terminator: "")
        fflush(stdout)
    }
}
