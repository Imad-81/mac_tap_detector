import Foundation

public struct WaveSynthesizer {
    public static let sampleRate: Double = 44100.0

    public static func createWavData(samples: [Float]) -> Data {
        var data = Data()
        let numSamples = Int32(samples.count)
        let numChannels: Int16 = 1
        let bitsPerSample: Int16 = 16
        let byteRate = Int32(sampleRate) * Int32(numChannels) * Int32(bitsPerSample / 8)
        let blockAlign = Int16(numChannels * (bitsPerSample / 8))
        let dataSize = numSamples * Int32(bitsPerSample / 8)
        let chunkSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        let subchunk1Size: Int32 = 16
        let audioFormat: Int16 = 1 // PCM
        data.append(contentsOf: withUnsafeBytes(of: subchunk1Size.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: numChannels.littleEndian) { Array($0) })
        let sampleRateInt32 = Int32(sampleRate)
        data.append(contentsOf: withUnsafeBytes(of: sampleRateInt32.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian) { Array($0) })

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Array($0) })

        // Samples
        for s in samples {
            let clamped = max(-1.0, min(1.0, s))
            let intSample = Int16(clamped * 32767.0)
            data.append(contentsOf: withUnsafeBytes(of: intSample.littleEndian) { Array($0) })
        }

        return data
    }

    /// Cartoon hollow bonk: pitch slide down with hollow resonance
    public static func generateBonk(duration: Double = 0.35) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: totalSamples)
        var phase: Double = 0
        var phase2: Double = 0

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Frequency sweep: 480 Hz dropping to 110 Hz
            let freq = 480.0 * exp(-progress * 4.5) + 110.0
            phase += 2.0 * .pi * freq / sampleRate
            phase2 += 2.0 * .pi * (freq * 2.3) / sampleRate

            let env = exp(-progress * 9.0) // Fast exponential decay
            let body = sin(phase) * 0.75 + sin(phase2) * 0.25
            samples[i] = Float(body * env)
        }
        return samples
    }

    /// Cartoon spring boing: frequency modulation with wobble
    public static func generateBoing(duration: Double = 0.45) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: totalSamples)
        var phase: Double = 0

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let progress = t / duration

            // Spring wobble frequency
            let modFreq = 14.0
            let carrier = 220.0 + progress * 320.0
            let freq = carrier + 80.0 * sin(2.0 * .pi * modFreq * t)

            phase += 2.0 * .pi * freq / sampleRate
            let env = exp(-progress * 4.0) * (1.0 - exp(-t * 80.0))
            samples[i] = Float(sin(phase) * env * 0.85)
        }
        return samples
    }

    /// Metallic pipe clank: multi-tonal inharmonic frequencies
    public static func generateMetal(duration: Double = 0.5) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: totalSamples)
        let freqs = [587.33, 845.0, 1175.0, 1760.0, 2489.0]
        let weights: [Double] = [0.35, 0.25, 0.2, 0.12, 0.08]
        var phases = [Double](repeating: 0, count: freqs.count)

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let progress = t / duration

            var sample = 0.0
            for j in 0..<freqs.count {
                phases[j] += 2.0 * .pi * freqs[j] / sampleRate
                let decayRate = 5.0 + Double(j) * 3.0
                let env = exp(-progress * decayRate)
                sample += sin(phases[j]) * weights[j] * env
            }

            // Click transient at start
            if t < 0.005 {
                let noise = Double.random(in: -1.0...1.0) * (1.0 - t / 0.005)
                sample += noise * 0.4
            }

            samples[i] = Float(sample)
        }
        return samples
    }

    /// Snappy pop / woodblock sound
    public static func generatePop(duration: Double = 0.12) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: totalSamples)
        var phase: Double = 0

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let progress = t / duration

            let freq = 900.0 * exp(-progress * 15.0) + 180.0
            phase += 2.0 * .pi * freq / sampleRate
            let env = exp(-progress * 25.0)
            samples[i] = Float(sin(phase) * env * 0.9)
        }
        return samples
    }

    /// Deep punchy thud / impact
    public static func generateThud(duration: Double = 0.25) -> [Float] {
        let totalSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: totalSamples)
        var phase: Double = 0

        for i in 0..<totalSamples {
            let t = Double(i) / sampleRate
            let progress = t / duration

            let freq = 160.0 * exp(-progress * 8.0) + 45.0
            phase += 2.0 * .pi * freq / sampleRate
            let env = exp(-progress * 9.0)

            var s = sin(phase) * env
            if t < 0.008 {
                s += Double.random(in: -0.3...0.3)
            }
            samples[i] = Float(s * 0.95)
        }
        return samples
    }

    /// Populates standard starter sounds into the specified directory if missing
    public static func ensureStarterSounds(in directory: URL) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let soundMakers: [(String, () -> [Float])] = [
            ("bonk.wav", { generateBonk() }),
            ("boing.wav", { generateBoing() }),
            ("metal.wav", { generateMetal() }),
            ("pop.wav", { generatePop() }),
            ("thud.wav", { generateThud() })
        ]

        for (filename, generator) in soundMakers {
            let fileURL = directory.appendingPathComponent(filename)
            if !fileManager.fileExists(atPath: fileURL.path) {
                let samples = generator()
                let wavData = createWavData(samples: samples)
                try? wavData.write(to: fileURL)
            }
        }
    }
}
