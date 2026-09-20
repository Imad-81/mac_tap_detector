# ⚡ MacBook Chassis Tap Detector

A tiny, responsive, and hilarious macOS application built for Apple Silicon MacBooks (tested and verified on the **MacBook Air M5**). Physically tap, slap, or knock the aluminum body of your MacBook, and it immediately detects the vibration through the built-in accelerometer and plays a random sound effect.

```text
*tap aluminum chassis*
        ↓
Apple SPU Accelerometer (~800 Hz)
        ↓
Dynamic transient isolation & jerk filter
        ↓
💥 TAP DETECTED
        ↓
🔊 💥 BONK!
```

---

## 🔬 Hardware & Sensor Architecture: How It Works

### 1. What Sensor/API is Being Used?
The application communicates directly with the **Bosch BMI286 MEMS 6-axis IMU** (Inertial Measurement Unit) integrated into the Apple Silicon logic board.

This sensor is managed by Apple's internal **Sensor Processing Unit (SPU)** and exposed via the macOS **IOKit Human Interface Device (HID)** subsystem as:
* **Service:** `AppleSPUHIDDevice`
* **Driver:** `AppleSPUHIDDriver`
* **Vendor Usage Page:** `0xFF00` (Apple Vendor defined)
* **Usage:** `3` (Accelerometer) and `9` (Gyroscope)
* **Sampling Rate:** Hardware configurable to 50, 100, 200, 400, or **800 Hz** (defaulted to 800 Hz / 1000 µs intervals)

### 2. Why This API Works on Modern macOS
* **Why not CoreMotion?** In the macOS SDK, Apple explicitly marks `CMMotionManager` as `API_UNAVAILABLE(macos)`. Attempting to use CoreMotion on macOS fails at compile time.
* **Why not AppleSMS?** The legacy Sudden Motion Sensor (`SMCMotionSensor`) was an Intel MacBook feature that was retired years ago and does not exist on Apple Silicon.
* **Why AppleSPUHIDDevice?** On Apple Silicon (M1/M2/M3/M4/M5), macOS routes internal environmental and motion sensors through the Sensor Processing Unit (SPU). By matching `AppleSPUHIDDriver` in IOKit and setting the activation properties (`SensorPropertyReportingState = 1`, `SensorPropertyPowerState = 1`, `ReportInterval = 1000`), the hardware activates. We can then open the corresponding `AppleSPUHIDDevice` via `IOHIDDeviceOpen` and register an input report callback.
* **No Root/Sudo Required:** Opening the device and reading reports succeeds with standard user permissions—no `sudo` required!

### 3. Data Format & Signal Processing
Incoming reports are 22-byte binary structures:
* Bytes 6–9: Signed 32-bit little-endian integer for X-axis
* Bytes 10–13: Signed 32-bit little-endian integer for Y-axis
* Bytes 14–17: Signed 32-bit little-endian integer for Z-axis
* Scaling: Dividing raw $Q_{16}$ integers by `65536.0` yields acceleration in standard gravitational units ($g$).

#### Tap Detection Algorithm:
1. **Baseline Resting Calibration:** Measures sensor noise over 2 seconds upon startup. The MacBook Air resting noise floor is remarkably quiet (~0.0022 g RMS, peak variation < 0.01 g).
2. **Gravity Tracking (DC Blocker):** An exponential moving average (EMA with $\alpha \approx 0.012$) tracks the constant 1.0g gravity vector and tilt.
3. **Dynamic Transient Magnitude:** $\mathbf{a}_{\text{dyn}} = \mathbf{a} - \mathbf{g}$. Magnitude $\|\mathbf{a}_{\text{dyn}}\| = \sqrt{x_{\text{dyn}}^2 + y_{\text{dyn}}^2 + z_{\text{dyn}}^2}$.
4. **Transient Jerk Filter:** Computes instantaneous rate-of-change ($\|\Delta \mathbf{a}\|$). A sharp physical chassis knock creates an impulse edge with high jerk, distinguishing it from slow desk wobbles or typing.
5. **Debounce / Cooldown:** Once triggered, a cooldown timer (default: 200 ms) suppresses secondary re-triggers caused by acoustic ringing or chassis vibration decay.

---

## 🛠️ Build & Run Instructions

### Prerequisites
* Apple Silicon Mac (M1, M2, M3, M4, M5 or later) running macOS 13+.
* Swift toolchain (included with Xcode or Command Line Tools: `xcode-select --install`).

### Build

```bash
# Debug build
swift build

# Production release build (optimized)
swift build -c release
```

### Run

```bash
# Run with default settings (console log mode)
swift run tap-detector

# Run with interactive ANSI live dashboard (Recommended!)
swift run tap-detector --debug
```

Or run the compiled binary directly:
```bash
./.build/release/tap-detector --debug
```

---

## 🕹️ Options & Tuning

| Flag | Argument | Description | Default |
|------|----------|-------------|---------|
| `-d, --debug` | *none* | Launches the rich ANSI real-time dashboard | Off (log mode) |
| `-s, --threshold` | `<float>` | Manually sets detection threshold in $g$ (e.g. `0.20`). Overrides auto-calibration. | Auto-calibrated |
| `--multiplier` | `<float>` | Multiplier applied to baseline noise during calibration | `5.0` |
| `-c, --cooldown` | `<ms>` | Debounce cooldown window in milliseconds | `200` |
| `-m, --mode` | `<name>` | Sound mode: `random`, `bonk`, `meme`, `system` | `random` |
| `--sounds-dir` | `<path>` | Custom directory containing sound effects | `./sounds` |
| `--no-calibrate` | *none* | Skips the initial 2-second resting noise calibration | Off |
| `--calibrate-time`| `<sec>` | Duration in seconds for noise calibration window | `2.0` |
| `--list-sounds` | *none* | Lists all available audio files and exits | - |
| `--test-audio` | *none* | Plays sample sounds through speakers and exits | - |

### Examples

```bash
# 1. Fun interactive live dashboard with cartoon bonk sounds:
swift run tap-detector --debug --mode bonk

# 2. High sensitivity (light taps trigger sounds):
swift run tap-detector --threshold 0.12 --cooldown 150

# 3. Heavy impact mode (hard knocks only, ignores typing):
swift run tap-detector --threshold 0.35

# 4. Instant start (skipping calibration):
swift run tap-detector --no-calibrate --threshold 0.20 --debug

# 5. Use native macOS system sounds (Pop, Ping, Tink, Funk):
swift run tap-detector --mode system
```

---

## 📺 Live Terminal Dashboard (`--debug`)

In debug mode, `tap-detector` renders a live, flicker-free terminal interface:

```text
╭──────────────────────────────────────────────────╮
│         ⚡ MACBOOK CHASSIS TAP DETECTOR ⚡         │
├──────────────────────────────────────────────────┤
│ Sensor:      CONNECTED (Apple SPU (Bosch BMI286))│
│ Sampling:    796 Hz                              │
│ Threshold:   [███░░░░░░░] 0.22g                  │
│ Cooldown:    200 ms                              │
│ Mode:        random (5 sounds ready)             │
├──────────────────────────────────────────────────┤
│ X:  -0.038 g                                     │
│ Y:  +0.030 g                                     │
│ Z:  -0.988 g                                     │
│ Dynamic:     [████░░░░░░░░░░] 0.084g             │
├──────────────────────────────────────────────────┤
│ Status:      💥 TAP DETECTED! 💥                 │
│ Last Event:  💥 #4 (1.42g) -> bonk.wav           │
│ Total Taps:  4                                   │
╰──────────────────────────────────────────────────╯
(Hit the laptop chassis to bonk. Press Ctrl+C to exit)
```

---

## 🔊 Adding Custom Sounds

1. Drop your sound files into the `sounds/` directory.
2. Supported formats:
   * `.wav`
   * `.mp3`
   * `.aiff` / `.aif`
   * `.m4a` / `.aac`
3. Starter sound pack included:
   * `bonk.wav`: Cartoon hollow pitch-drop bonk
   * `boing.wav`: Spring wobble cartoon boing
   * `metal.wav`: Metallic pipe clank
   * `pop.wav`: Crisp woodblock pop
   * `thud.wav`: Low punchy bass impact

Run `swift run tap-detector --list-sounds` at any time to inspect loaded audio files.

---

## ⚠️ Known Limitations & Notes
1. **Apple Silicon Only:** Relies on the SPU (`AppleSPUHIDDevice`) architecture introduced on Apple Silicon Macs. Not compatible with legacy Intel Macs.
2. **Resting Calibration:** For best results, keep the MacBook resting on a desk for the first 2 seconds of launch while it profiles ambient desk vibrations.
3. **Typing Isolation:** Normal typing on the keyboard typically produces dynamic vibrations $< 0.06 g$. If you find vigorous typing triggering sounds, slightly raise the threshold (e.g. `--threshold 0.28`).
