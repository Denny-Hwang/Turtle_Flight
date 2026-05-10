import Foundation
import AVFoundation

/// Manages all game audio — BGM, vehicle SFX, and UI sounds.
/// Uses synthesized audio tones since asset files are generated at runtime.
final class AudioManager {
    static let shared = AudioManager()

    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayers: [String: AVAudioPlayer] = [:]
    private var activeLoopPlayer: AVAudioPlayer?

    /// Cached WAV blobs keyed by deterministic (kind, parameters) so we don't
    /// re-synthesise the same 30s BGM (~1.3 MB) every time a flight starts.
    private var wavCache: [String: Data] = [:]

    /// Theme/name we last requested - so we can resume after an interruption.
    private var lastBGMTheme: String?
    private var lastVehicleSound: String?

    private(set) var isMuted: Bool {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: Keys.muted)
        }
    }
    /// BGM volume in [0, 1]. Persisted across launches via UserDefaults.
    /// Applied live when changed — the active BGM player gets the new
    /// volume immediately so the SettingsView slider reads as connected.
    private(set) var bgmVolume: Float {
        didSet {
            UserDefaults.standard.set(bgmVolume, forKey: Keys.bgmVolume)
            bgmPlayer?.volume = bgmVolume
        }
    }
    /// SFX volume in [0, 1]. The vehicle loop adopts the new volume live;
    /// one-shot SFX (boost, star, ring) read this on every fire so the
    /// next tap reflects the latest setting.
    private(set) var sfxVolume: Float {
        didSet {
            UserDefaults.standard.set(sfxVolume, forKey: Keys.sfxVolume)
            // Vehicle loop runs at sfxVolume * 0.4 so apply the same scale.
            activeLoopPlayer?.volume = sfxVolume * 0.4
        }
    }

    private enum Keys {
        static let muted = "audio.muted"
        static let bgmVolume = "audio.bgmVolume"
        static let sfxVolume = "audio.sfxVolume"
    }

    /// Default volumes used on first launch. Pulled out so the SettingsView
    /// "reset to defaults" path has a single source of truth.
    static let defaultBGMVolume: Float = 0.3
    static let defaultSFXVolume: Float = 0.5

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: Keys.muted)
        // Load persisted volumes, falling through to the design defaults
        // when no value has been written yet (UserDefaults returns 0 for
        // missing Float keys, which would silently mute on first launch).
        let storedBGM = UserDefaults.standard.object(forKey: Keys.bgmVolume) as? Float
        let storedSFX = UserDefaults.standard.object(forKey: Keys.sfxVolume) as? Float
        bgmVolume = storedBGM ?? Self.defaultBGMVolume
        sfxVolume = storedSFX ?? Self.defaultSFXVolume
        configureAudioSession()
        registerSessionObservers()
    }

    // MARK: - Public volume API (settings)

    /// Set BGM volume in [0, 1]. Clamps out-of-range values so a slider
    /// glitch can't push us past the AVAudioPlayer's accepted range.
    func setBGMVolume(_ value: Float) {
        bgmVolume = max(0, min(1, value))
    }

    /// Set SFX volume in [0, 1].
    func setSFXVolume(_ value: Float) {
        sfxVolume = max(0, min(1, value))
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio not critical — continue without it
        }
    }

    private func registerSessionObservers() {
        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }

        switch type {
        case .began:
            // Phone call, Siri, etc. — iOS already paused us. Just drop our refs
            // so we resume cleanly on `.ended`.
            bgmPlayer?.pause()
            activeLoopPlayer?.pause()
        case .ended:
            // Apple recommends only resuming if the system says we should.
            let optsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let opts = AVAudioSession.InterruptionOptions(rawValue: optsRaw)
            if opts.contains(.shouldResume), !isMuted {
                bgmPlayer?.play()
                activeLoopPlayer?.play()
            }
        @unknown default:
            break
        }
    }

    @objc private func handleRouteChange(_ note: Notification) {
        guard
            let info = note.userInfo,
            let reasonRaw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw),
            reason == .oldDeviceUnavailable
        else { return }
        // User unplugged headphones / disconnected AirPods — Apple HIG says
        // pause rather than blast the speaker.
        bgmPlayer?.pause()
        activeLoopPlayer?.pause()
    }

    // MARK: - BGM (Procedurally Generated)

    func startBGM(theme: String = "sky") {
        lastBGMTheme = theme
        guard !isMuted else { return }
        stopBGM()

        let key = "bgm:\(theme)"
        let data: Data
        if let cached = wavCache[key] {
            data = cached
        } else {
            data = SynthAudio.generateBGM(theme: theme, durationSeconds: 30)
            wavCache[key] = data
        }
        play(data: data, volume: bgmVolume, loops: -1) { [weak self] player in
            self?.bgmPlayer = player
        }
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }

    // MARK: - Vehicle SFX

    func playVehicleSound(_ soundName: String) {
        lastVehicleSound = soundName
        guard !isMuted else { return }
        stopVehicleLoop()

        let key = "vehicle:\(soundName)"
        let data: Data
        if let cached = wavCache[key] {
            data = cached
        } else {
            data = SynthAudio.generateVehicleSFX(name: soundName, durationSeconds: 4)
            wavCache[key] = data
        }
        play(data: data, volume: sfxVolume * 0.4, loops: -1) { [weak self] player in
            self?.activeLoopPlayer = player
        }
    }

    func stopVehicleLoop() {
        activeLoopPlayer?.stop()
        activeLoopPlayer = nil
    }

    // MARK: - One-shot SFX

    func playBoost() {
        guard !isMuted else { return }
        let data = SynthAudio.generateBoostSFX(durationSeconds: 0.6)
        playOneShot(data: data, volume: sfxVolume * 0.7)
    }

    func playStarCollect() {
        guard !isMuted else { return }
        let data = SynthAudio.generateStarCollectSFX(durationSeconds: 0.4)
        playOneShot(data: data, volume: sfxVolume * 0.6)
    }

    func playRingPass() {
        guard !isMuted else { return }
        let data = SynthAudio.generateRingPassSFX(durationSeconds: 0.5)
        playOneShot(data: data, volume: sfxVolume * 0.8)
    }

    func playStageClear() {
        guard !isMuted else { return }
        let data = SynthAudio.generateStageClearSFX(durationSeconds: 1.2)
        playOneShot(data: data, volume: sfxVolume)
    }

    func playStageFail() {
        guard !isMuted else { return }
        let data = SynthAudio.generateStageFailSFX(durationSeconds: 0.8)
        playOneShot(data: data, volume: sfxVolume * 0.7)
    }

    /// Brief low-frequency thump for terrain/obstacle brushes. Distinct
    /// from `playStageFail` (which is the bigger "mission lost" cue) — this
    /// is more of a physical "ouch, that hurt" beat to pair with the
    /// heavy-haptic generator on `MissionEngine.registerCollision()`.
    func playCollision() {
        guard !isMuted else { return }
        let data = SynthAudio.generateCollisionSFX(durationSeconds: 0.25)
        playOneShot(data: data, volume: sfxVolume * 0.6)
    }

    /// Single high-pitched chirp used for the 5/3/1-second mission-timer
    /// countdown. Distinct from `playButtonTap` (which is a flatter UI
    /// click) — this rises slightly so consecutive ticks feel urgent.
    func playTimerTick() {
        guard !isMuted else { return }
        let data = SynthAudio.generateTimerTickSFX(durationSeconds: 0.18)
        playOneShot(data: data, volume: sfxVolume * 0.55)
    }

    func playButtonTap() {
        guard !isMuted else { return }
        let data = SynthAudio.generateButtonTapSFX(durationSeconds: 0.1)
        playOneShot(data: data, volume: sfxVolume * 0.3)
    }

    // MARK: - Controls

    func setMuted(_ muted: Bool) {
        isMuted = muted
        if muted {
            bgmPlayer?.pause()
            activeLoopPlayer?.pause()
        } else {
            // Re-engage what was last requested. If players exist, just resume;
            // otherwise re-spawn them via the same code path that built the
            // first ones (this hits the wavCache, so no re-synthesis cost).
            if bgmPlayer != nil { bgmPlayer?.play() }
            else if let theme = lastBGMTheme { startBGM(theme: theme) }

            if activeLoopPlayer != nil { activeLoopPlayer?.play() }
            else if let name = lastVehicleSound { playVehicleSound(name) }
        }
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    func stopAll() {
        bgmPlayer?.stop()
        bgmPlayer = nil
        activeLoopPlayer?.stop()
        activeLoopPlayer = nil
        sfxPlayers.values.forEach { $0.stop() }
        sfxPlayers.removeAll()
    }

    // MARK: - Private Helpers

    private func play(data: Data, volume: Float, loops: Int, completion: @escaping (AVAudioPlayer?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let player = try AVAudioPlayer(data: data)
                player.volume = volume
                player.numberOfLoops = loops
                player.prepareToPlay()
                player.play()
                DispatchQueue.main.async { completion(player) }
            } catch {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    private func playOneShot(data: Data, volume: Float) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let player = try AVAudioPlayer(data: data)
                player.volume = volume
                player.numberOfLoops = 0
                player.prepareToPlay()
                player.play()
                let key = UUID().uuidString
                DispatchQueue.main.async {
                    self?.sfxPlayers[key] = player
                    // Clean up after playback
                    DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) {
                        self?.sfxPlayers.removeValue(forKey: key)
                    }
                }
            } catch {
                // Non-critical — skip
            }
        }
    }
}

// MARK: - Synthesized Audio Generator

/// Generates WAV audio data procedurally — no asset files needed.
enum SynthAudio {
    private static let sampleRate: Double = 22050
    private static let bitsPerSample: Int = 16

    // MARK: - BGM

    static func generateBGM(theme: String, durationSeconds: Double) -> Data {
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)

        let baseFreqs: [Double]
        switch theme {
        case "space":
            baseFreqs = [130.81, 164.81, 196.0, 261.63]  // C3 E3 G3 C4 — ethereal
        case "ocean":
            baseFreqs = [146.83, 174.61, 220.0, 293.66]   // D3 F3 A3 D4 — flowing
        default: // sky
            baseFreqs = [196.0, 246.94, 293.66, 392.0]    // G3 B3 D4 G4 — bright
        }

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            // Layered pads
            for (idx, freq) in baseFreqs.enumerated() {
                let phaseOffset = Double(idx) * 0.7
                let lfo = sin(t * 0.3 + phaseOffset) * 0.3 + 0.7
                sample += sin(2.0 * .pi * freq * t + phaseOffset) * lfo * 0.15
            }

            // Slow volume swell
            let envelope = sin(.pi * t / durationSeconds) * 0.8 + 0.2

            samples[i] = Int16(clamping: Int(sample * envelope * 12000))
        }

        return wavData(from: samples)
    }

    // MARK: - Vehicle SFX

    static func generateVehicleSFX(name: String, durationSeconds: Double) -> Data {
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            switch name {
            case "jet_whoosh":
                // Jet engine: low rumble + high hiss
                sample = sin(2.0 * .pi * 80.0 * t) * 0.4
                sample += whiteNoise() * 0.15 * (0.8 + sin(t * 3.0) * 0.2)
            case "glide_wind":
                // Wind: filtered noise with gentle modulation
                sample = whiteNoise() * 0.2 * (0.6 + sin(t * 1.5) * 0.4)
            case "copter_spin":
                // Helicopter: periodic thump
                let chopRate = 12.0
                let chop = sin(2.0 * .pi * chopRate * t)
                sample = sin(2.0 * .pi * 60.0 * t) * max(chop, 0) * 0.5
            case "magic_swoosh":
                // Magical: shimmering harmonics
                sample = sin(2.0 * .pi * 440.0 * t + sin(t * 6.0) * 2.0) * 0.15
                sample += sin(2.0 * .pi * 660.0 * t) * 0.08 * (0.5 + sin(t * 2.0) * 0.5)
            case "balloon_inflate":
                // Balloon: soft air flow
                sample = whiteNoise() * 0.1 * (0.5 + sin(t * 0.8) * 0.5)
                sample += sin(2.0 * .pi * 200.0 * t) * 0.05
            case "ear_whirl":
                // Whirling ears: mid-frequency oscillation
                let whirlRate = 8.0
                sample = sin(2.0 * .pi * 150.0 * t) * 0.3 * abs(sin(2.0 * .pi * whirlRate * t))
            case "cloud_whoosh":
                // Cloud surf: gentle whoosh
                sample = whiteNoise() * 0.12 * (0.7 + sin(t * 1.0) * 0.3)
                sample += sin(2.0 * .pi * 120.0 * t) * 0.05
            default:
                sample = whiteNoise() * 0.1
            }

            // Smooth loop crossfade at boundaries
            let fadeLen = 0.1
            let fadeIn = min(t / fadeLen, 1.0)
            let fadeOut = min((durationSeconds - t) / fadeLen, 1.0)
            samples[i] = Int16(clamping: Int(sample * fadeIn * fadeOut * 8000))
        }

        return wavData(from: samples)
    }

    // MARK: - UI / Game SFX

    static func generateBoostSFX(durationSeconds: Double) -> Data {
        return generateTone(frequencies: [120, 180, 240], duration: durationSeconds, envelope: .attack, amplitude: 0.6)
    }

    static func generateStarCollectSFX(durationSeconds: Double) -> Data {
        // Rising chime
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let progress = t / durationSeconds
            let freq = 600.0 + progress * 800.0  // Rising from 600 to 1400 Hz
            let env = (1.0 - progress) * (1.0 - progress)
            let sample = sin(2.0 * .pi * freq * t) * env * 0.5
            samples[i] = Int16(clamping: Int(sample * 16000))
        }
        return wavData(from: samples)
    }

    static func generateRingPassSFX(durationSeconds: Double) -> Data {
        // Success ding-ding
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let freq1 = 523.25  // C5
            let freq2 = 659.26  // E5
            let switch_t = durationSeconds * 0.45
            let freq = t < switch_t ? freq1 : freq2
            let localT = t < switch_t ? t : t - switch_t
            let env = exp(-localT * 6.0)
            let sample = sin(2.0 * .pi * freq * t) * env * 0.6
            samples[i] = Int16(clamping: Int(sample * 16000))
        }
        return wavData(from: samples)
    }

    static func generateStageClearSFX(durationSeconds: Double) -> Data {
        // Triumphant ascending arpeggio: C E G C
        let notes: [(freq: Double, start: Double)] = [
            (523.25, 0.0), (659.26, 0.25), (783.99, 0.5), (1046.5, 0.75)
        ]
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            var sample = 0.0
            for note in notes {
                let localT = t - note.start
                guard localT >= 0 else { continue }
                let env = exp(-localT * 2.5)
                sample += sin(2.0 * .pi * note.freq * t) * env * 0.35
            }
            samples[i] = Int16(clamping: Int(sample * 16000))
        }
        return wavData(from: samples)
    }

    static func generateStageFailSFX(durationSeconds: Double) -> Data {
        // Descending sad tone
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let progress = t / durationSeconds
            let freq = 400.0 - progress * 200.0  // Descending
            let env = (1.0 - progress)
            let sample = sin(2.0 * .pi * freq * t) * env * 0.4
            samples[i] = Int16(clamping: Int(sample * 16000))
        }
        return wavData(from: samples)
    }

    static func generateButtonTapSFX(durationSeconds: Double) -> Data {
        return generateTone(frequencies: [800], duration: durationSeconds, envelope: .decay, amplitude: 0.3)
    }

    /// 1100Hz tick that rises ~50Hz across its duration. Short enough to
    /// not muddle voiceover, distinct from button taps so the player reads
    /// it as urgency rather than feedback.
    static func generateTimerTickSFX(durationSeconds: Double) -> Data {
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let progress = t / durationSeconds
            let freq = 1100.0 + progress * 50.0
            // Sharp attack, quick decay → reads as a "tick" rather than a tone.
            let env = (progress < 0.05 ? progress / 0.05 : exp(-(progress - 0.05) * 8.0))
            let sample = sin(2.0 * .pi * freq * t) * env * 0.55
            samples[i] = Int16(clamping: Int(sample * 16000))
        }
        return wavData(from: samples)
    }

    /// Short low-frequency thump (~80Hz) with a fast decay envelope and a
    /// touch of noise so it reads as a physical brush rather than a tone.
    /// Pairs with `UIImpactFeedbackGenerator(style: .heavy)` on collision.
    static func generateCollisionSFX(durationSeconds: Double) -> Data {
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let progress = t / durationSeconds
            // Fast exponential decay — most of the energy in the first 60ms.
            let env = exp(-progress * 12.0)
            // Two layered low sines for a chunkier thump than a pure tone.
            var sample = sin(2.0 * .pi * 80.0 * t) * 0.5
            sample += sin(2.0 * .pi * 120.0 * t) * 0.25
            // Brief noise burst at the very front for the "thud" attack.
            sample += whiteNoise() * 0.15 * exp(-progress * 25.0)
            samples[i] = Int16(clamping: Int(sample * env * 18000))
        }
        return wavData(from: samples)
    }

    // MARK: - Helpers

    private enum Envelope { case attack, decay, sustain }

    private static func generateTone(frequencies: [Double], duration: Double, envelope: Envelope, amplitude: Double) -> Data {
        let numSamples = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: numSamples)
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let progress = t / duration
            var sample = 0.0
            for freq in frequencies {
                sample += sin(2.0 * .pi * freq * t) / Double(frequencies.count)
            }
            let env: Double
            switch envelope {
            case .attack:  env = min(progress * 4.0, 1.0) * (1.0 - progress)
            case .decay:   env = exp(-progress * 8.0)
            case .sustain: env = min(progress * 10.0, 1.0) * min((1.0 - progress) * 10.0, 1.0)
            }
            samples[i] = Int16(clamping: Int(sample * env * amplitude * 20000))
        }
        return wavData(from: samples)
    }

    private static func whiteNoise() -> Double {
        Double.random(in: -1.0...1.0)
    }

    /// Creates a valid WAV file in memory from raw PCM samples
    private static func wavData(from samples: [Int16]) -> Data {
        let numChannels: Int = 1
        let byteRate = Int(sampleRate) * numChannels * (bitsPerSample / 8)
        let blockAlign = numChannels * (bitsPerSample / 8)
        let dataSize = samples.count * (bitsPerSample / 8)
        let fileSize = 36 + dataSize

        // Pre-size to avoid the O(N) reallocation during the per-sample append
        // loop. 44 bytes of header + 2 bytes per sample.
        var data = Data()
        data.reserveCapacity(44 + dataSize)

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        data.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })        // Subchunk1Size
        data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })         // PCM format
        data.append(contentsOf: withUnsafeBytes(of: UInt16(numChannels).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(Int(sampleRate)).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Array($0) })

        // data subchunk
        data.append(contentsOf: "data".utf8)
        data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
        for sample in samples {
            data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }

        return data
    }
}
