import Foundation

public struct CalibrationResult {
    public let sampleCount: Int
    public let duration: Double
    public let meanGravity: (x: Double, y: Double, z: Double)
    public let meanMagnitude: Double
    public let peakNoise: Double
    public let rmsNoise: Double
    public let recommendedThreshold: Double

    public var summary: String {
        return String(
            format: "Calibration (%d samples in %.1fs): Baseline=%.3fg, PeakNoise=%.4fg, RMS=%.4fg -> Threshold=%.3fg",
            sampleCount, duration, meanMagnitude, peakNoise, rmsNoise, recommendedThreshold
        )
    }
}

public final class SensorCalibrator {
    private var samples: [AccelSample] = []
    private let targetDuration: Double
    private let multiplier: Double
    private let minimumFloor: Double

    public init(duration: Double = 2.0, multiplier: Double = 5.0, minimumFloor: Double = 0.08) {
        self.targetDuration = duration
        self.multiplier = multiplier
        self.minimumFloor = minimumFloor
    }

    public func addSample(_ sample: AccelSample) {
        samples.append(sample)
    }

    public var isComplete: Bool {
        guard let first = samples.first, let last = samples.last else { return false }
        return (last.timestamp - first.timestamp) >= targetDuration
    }

    public var progress: Double {
        guard let first = samples.first, let last = samples.last else { return 0.0 }
        let elapsed = last.timestamp - first.timestamp
        return min(1.0, elapsed / targetDuration)
    }

    public func finish() -> CalibrationResult {
        guard !samples.isEmpty else {
            return CalibrationResult(
                sampleCount: 0,
                duration: 0,
                meanGravity: (0, 0, -1.0),
                meanMagnitude: 1.0,
                peakNoise: 0.02,
                rmsNoise: 0.005,
                recommendedThreshold: minimumFloor
            )
        }

        let count = Double(samples.count)
        let meanX = samples.reduce(0.0) { $0 + $1.x } / count
        let meanY = samples.reduce(0.0) { $0 + $1.y } / count
        let meanZ = samples.reduce(0.0) { $0 + $1.z } / count
        let meanMag = (meanX * meanX + meanY * meanY + meanZ * meanZ).squareRoot()

        var peakNoise = 0.0
        var sumSqDynamic = 0.0

        for s in samples {
            let dx = s.x - meanX
            let dy = s.y - meanY
            let dz = s.z - meanZ
            let dyn = (dx * dx + dy * dy + dz * dz).squareRoot()
            if dyn > peakNoise {
                peakNoise = dyn
            }
            sumSqDynamic += dyn * dyn
        }

        let rmsNoise = (sumSqDynamic / count).squareRoot()
        let duration = (samples.last?.timestamp ?? 0) - (samples.first?.timestamp ?? 0)

        // Threshold adapts to peak noise with configurable multiplier, clamped above minimum safety floor
        let calculated = max(minimumFloor, peakNoise * multiplier)

        return CalibrationResult(
            sampleCount: samples.count,
            duration: duration,
            meanGravity: (meanX, meanY, meanZ),
            meanMagnitude: meanMag,
            peakNoise: peakNoise,
            rmsNoise: rmsNoise,
            recommendedThreshold: calculated
        )
    }
}
