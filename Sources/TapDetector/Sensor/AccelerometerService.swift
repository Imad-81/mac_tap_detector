import Foundation
import IOKit
import IOKit.hid

public struct AccelSample {
    public let timestamp: Double
    public let x: Double
    public let y: Double
    public let z: Double
    public let magnitude: Double

    public init(timestamp: Double, x: Double, y: Double, z: Double) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
        self.z = z
        self.magnitude = (x * x + y * y + z * z).squareRoot()
    }
}

public final class AccelerometerService {
    public typealias SampleHandler = (AccelSample) -> Void

    private var hidDevice: IOHIDDevice?
    private var isRunning = false
    private var reportBuffer = [UInt8](repeating: 0, count: 4096)
    private var sampleHandler: SampleHandler?

    // Rate estimation
    private var sampleCount: Int = 0
    private var lastRateCalcTime: Double = CFAbsoluteTimeGetCurrent()
    public private(set) var currentHz: Double = 0.0

    public init() {}

    deinit {
        stop()
    }

    public func start(on runLoop: CFRunLoop = CFRunLoopGetCurrent(), handler: @escaping SampleHandler) throws {
        guard !isRunning else { return }
        self.sampleHandler = handler

        // 1. Wake the AppleSPU HID Driver
        wakeSPUDriver()

        // 2. Discover and open the SPU Accelerometer Device
        guard let device = findAccelerometerDevice() else {
            throw SensorError.deviceNotFound
        }

        let openRet = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openRet == kIOReturnSuccess else {
            throw SensorError.cannotOpenDevice(openRet)
        }

        self.hidDevice = device
        self.isRunning = true
        self.lastRateCalcTime = CFAbsoluteTimeGetCurrent()
        self.sampleCount = 0

        // 3. Register input report callback
        let contextPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: IOHIDReportCallback = { context, result, sender, type, reportID, report, reportLength in
            guard let context = context, reportLength >= 18 else { return }
            let service = Unmanaged<AccelerometerService>.fromOpaque(context).takeUnretainedValue()

            // Safe unaligned little-endian reading of 32-bit signed integers
            func readInt32LE(_ ptr: UnsafePointer<UInt8>, offset: Int) -> Int32 {
                let b0 = UInt32(ptr[offset])
                let b1 = UInt32(ptr[offset + 1]) << 8
                let b2 = UInt32(ptr[offset + 2]) << 16
                let b3 = UInt32(ptr[offset + 3]) << 24
                return Int32(bitPattern: b0 | b1 | b2 | b3)
            }

            let rawX = readInt32LE(report, offset: 6)
            let rawY = readInt32LE(report, offset: 10)
            let rawZ = readInt32LE(report, offset: 14)

            // Scale Q16 to G (1 g = 65536 units)
            let scale = 65536.0
            let x = Double(rawX) / scale
            let y = Double(rawY) / scale
            let z = Double(rawZ) / scale

            let now = CFAbsoluteTimeGetCurrent()
            let sample = AccelSample(timestamp: now, x: x, y: y, z: z)
            service.recordSample(sample)
        }

        IOHIDDeviceRegisterInputReportCallback(device, &reportBuffer, reportBuffer.count, callback, contextPtr)
        IOHIDDeviceScheduleWithRunLoop(device, runLoop, CFRunLoopMode.defaultMode.rawValue)
    }

    public func stop() {
        guard isRunning, let device = hidDevice else { return }
        IOHIDDeviceRegisterInputReportCallback(device, &reportBuffer, reportBuffer.count, nil, nil)
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        self.hidDevice = nil
        self.isRunning = false
    }

    private func recordSample(_ sample: AccelSample) {
        sampleCount += 1
        let now = sample.timestamp
        let elapsed = now - lastRateCalcTime
        if elapsed >= 0.5 {
            currentHz = Double(sampleCount) / elapsed
            sampleCount = 0
            lastRateCalcTime = now
        }
        sampleHandler?(sample)
    }

    private func wakeSPUDriver() {
        guard let matching = IOServiceMatching("AppleSPUHIDDriver") else { return }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return }

        var svc = IOIteratorNext(iterator)
        while svc != 0 {
            var one: Int32 = 1
            var interval: Int32 = 1000 // 1000 us = 1ms (~800-1000 Hz)
            let numOne = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &one)
            let numInterval = CFNumberCreate(kCFAllocatorDefault, .sInt32Type, &interval)

            IORegistryEntrySetCFProperty(svc, "SensorPropertyReportingState" as CFString, numOne)
            IORegistryEntrySetCFProperty(svc, "SensorPropertyPowerState" as CFString, numOne)
            IORegistryEntrySetCFProperty(svc, "ReportInterval" as CFString, numInterval)

            IOObjectRelease(svc)
            svc = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
    }

    private func findAccelerometerDevice() -> IOHIDDevice? {
        guard let matching = IOServiceMatching("AppleSPUHIDDevice") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return nil }

        var svc = IOIteratorNext(iterator)
        var foundDevice: IOHIDDevice? = nil

        while svc != 0 {
            let pageRef = IORegistryEntryCreateCFProperty(svc, "PrimaryUsagePage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            let usageRef = IORegistryEntryCreateCFProperty(svc, "PrimaryUsage" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()

            var page: Int64 = 0
            var usage: Int64 = 0
            if let pageNum = pageRef as? NSNumber { page = pageNum.int64Value }
            if let usageNum = usageRef as? NSNumber { usage = usageNum.int64Value }

            // Vendor-defined page 0xFF00, Usage 3 = Accelerometer
            if page == 0xFF00 && usage == 3 {
                if let hid = IOHIDDeviceCreate(kCFAllocatorDefault, svc) {
                    foundDevice = hid
                    IOObjectRelease(svc)
                    break
                }
            }
            IOObjectRelease(svc)
            svc = IOIteratorNext(iterator)
        }
        IOObjectRelease(iterator)
        return foundDevice
    }

    public enum SensorError: LocalizedError {
        case deviceNotFound
        case cannotOpenDevice(IOReturn)

        public var errorDescription: String? {
            switch self {
            case .deviceNotFound:
                return "Apple SPU Accelerometer (AppleSPUHIDDevice) not found in IOKit registry. Ensure you are running on an Apple Silicon Mac."
            case .cannotOpenDevice(let code):
                return "Failed to open AppleSPUHIDDevice (IOKit error code: \(code))."
            }
        }
    }
}
