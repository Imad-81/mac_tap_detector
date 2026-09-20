import Foundation

public struct ProcessedSignal {
    public let sample: AccelSample
    public let gravity: (x: Double, y: Double, z: Double)
    public let dynamic: (x: Double, y: Double, z: Double)
    public let dynamicMagnitude: Double
    public let jerk: Double
}

public final class SignalFilter {
    private var gravX: Double = 0.0
    private var gravY: Double = 0.0
    private var gravZ: Double = -1.0
    private var isInitialized = false

    private var prevX: Double = 0.0
    private var prevY: Double = 0.0
    private var prevZ: Double = -1.0

    /// Alpha for gravity low-pass EMA (~0.01 at 800 Hz corresponds to ~1.2 Hz cutoff)
    private let alpha: Double

    public init(alpha: Double = 0.012) {
        self.alpha = alpha
    }

    public func reset(with sample: AccelSample) {
        gravX = sample.x
        gravY = sample.y
        gravZ = sample.z
        prevX = sample.x
        prevY = sample.y
        prevZ = sample.z
        isInitialized = true
    }

    public func process(_ sample: AccelSample) -> ProcessedSignal {
        if !isInitialized {
            reset(with: sample)
        }

        // 1. First difference (Jerk / transient spike rate)
        let dx = sample.x - prevX
        let dy = sample.y - prevY
        let dz = sample.z - prevZ
        let jerk = (dx * dx + dy * dy + dz * dz).squareRoot()

        prevX = sample.x
        prevY = sample.y
        prevZ = sample.z

        // 2. Exponential Moving Average to isolate the constant gravitational component
        gravX = (1.0 - alpha) * gravX + alpha * sample.x
        gravY = (1.0 - alpha) * gravY + alpha * sample.y
        gravZ = (1.0 - alpha) * gravZ + alpha * sample.z

        // 3. Dynamic acceleration (transient vibration) = Total - Gravity
        let dynX = sample.x - gravX
        let dynY = sample.y - gravY
        let dynZ = sample.z - gravZ
        let dynMag = (dynX * dynX + dynY * dynY + dynZ * dynZ).squareRoot()

        return ProcessedSignal(
            sample: sample,
            gravity: (gravX, gravY, gravZ),
            dynamic: (dynX, dynY, dynZ),
            dynamicMagnitude: dynMag,
            jerk: jerk
        )
    }
}
