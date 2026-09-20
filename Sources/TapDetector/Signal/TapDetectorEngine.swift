import Foundation

public struct TapEvent {
    public let timestamp: Double
    public let peakMagnitude: Double
    public let jerk: Double
    public let tapIndex: Int

    public var description: String {
        return String(format: "Tap #%d: Peak=%.3fg (jerk=%.3fg)", tapIndex, peakMagnitude, jerk)
    }
}

public final class TapDetectorEngine {
    public typealias TapHandler = (TapEvent) -> Void

    public var threshold: Double
    public var cooldownDuration: Double
    public var minJerkRatio: Double

    private let filter: SignalFilter
    private var lastTapTimestamp: Double = 0.0
    public private(set) var totalTaps: Int = 0

    // Peak tracking during impact
    private var isImpacting = false
    private var currentPeakDynamic: Double = 0.0

    public var onTap: TapHandler?

    public init(
        threshold: Double = 0.22,
        cooldownSeconds: Double = 0.20,
        minJerkRatio: Double = 0.25,
        filterAlpha: Double = 0.012
    ) {
        self.threshold = threshold
        self.cooldownDuration = cooldownSeconds
        self.minJerkRatio = minJerkRatio
        self.filter = SignalFilter(alpha: filterAlpha)
    }

    public func updateThreshold(_ newThreshold: Double) {
        self.threshold = newThreshold
    }

    public func updateCooldown(_ newCooldownSeconds: Double) {
        self.cooldownDuration = newCooldownSeconds
    }

    public func processSample(_ sample: AccelSample) -> (signal: ProcessedSignal, detectedTap: TapEvent?) {
        let signal = filter.process(sample)
        let now = sample.timestamp
        let timeSinceLastTap = now - lastTapTimestamp

        var detectedEvent: TapEvent? = nil

        // If within cooldown window, suppress re-triggering from acoustic ringing / chassis rebound
        if timeSinceLastTap < cooldownDuration {
            return (signal, nil)
        }

        // Detection criteria:
        // 1. Dynamic vibration magnitude exceeds threshold
        // 2. Jerk (instantaneous rate of change) confirms sharp mechanical edge vs smooth movement
        let minJerkRequired = threshold * minJerkRatio
        let isSharpSpike = signal.dynamicMagnitude >= threshold && signal.jerk >= minJerkRequired
        let isStrongImpact = signal.dynamicMagnitude >= (threshold * 1.6)

        if isSharpSpike || isStrongImpact {
            lastTapTimestamp = now
            totalTaps += 1
            let event = TapEvent(
                timestamp: now,
                peakMagnitude: signal.dynamicMagnitude,
                jerk: signal.jerk,
                tapIndex: totalTaps
            )
            detectedEvent = event
            onTap?(event)
        }

        return (signal, detectedEvent)
    }
}
