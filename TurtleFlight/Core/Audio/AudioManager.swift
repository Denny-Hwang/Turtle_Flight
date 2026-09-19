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

    // MARK: - Asset hook (Phase 4)

    /// Bundled audio wins over synthesis. Drop `bgm_sky.m4a`,
    /// `vehicle_jet_whoosh.m4a`, `sfx_ring_pass.m4a`, … into the app
    /// bundle (see `docs/AUDIO_AUDIT.md` for the full name table) and
    /// they are picked up here with no code change; anything missing
    /// keeps the synthesised fallback so a partial asset drop is fine.
    static let assetExtensions = ["m4a", "caf", "wav", "mp3"]

    static func assetURL(named name: String, bundle: Bundle = .main) -> URL? {
        for ext in assetExtensions {
            if let url = bundle.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    /// Cached sound payload: bundled asset bytes when present, otherwise
    /// the synthesised WAV from `synth`.
    private func soundData(key: String, asset: String, synth: () -> Data) -> Data {
        if let cached = wavCache[key] { return cached }
        let data: Data
        if let url = Self.assetURL(named: asset), let bytes = try? Data(contentsOf: url) {
            data = bytes
        } else {
            data = synth()
        }
        wavCache[key] = data
        return data
    }

    // MARK: - BGM (bundled asset or procedurally generated)

    func startBGM(theme: String = "sky") {
        lastBGMTheme = theme
        guard !isMuted else { return }
        stopBGM()

        let data = soundData(key: "bgm:\(theme)", asset: "bgm_\(theme)") {
            SynthAudio.generateBGM(theme: theme, durationSeconds: 32)
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

        let data = soundData(key: "vehicle:\(soundName)", asset: "vehicle_\(soundName)") {
            SynthAudio.generateVehicleSFX(name: soundName, durationSeconds: 4)
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
        let data = soundData(key: "sfx:boost", asset: "sfx_boost") {
            SynthAudio.generateBoostSFX(durationSeconds: 0.6)
        }
        playOneShot(data: data, volume: sfxVolume * 0.7)
    }

    func playStarCollect() {
        guard !isMuted else { return }
        let data = soundData(key: "sfx:star", asset: "sfx_star_collect") {
            SynthAudio.generateStarCollectSFX(durationSeconds: 0.4)
        }
        playOneShot(data: data, volume: sfxVolume * 0.6)
    }

    func playRingPass() {
        guard !isMuted else { return }
        let data = soundData(key: "sfx:ring", asset: "sfx_ring_pass") {
            SynthAudio.generateRingPassSFX(durationSeconds: 0.5)
        }
        playOneShot(data: data, volume: sfxVolume * 0.8)
    }

    func playStageClear() {
        guard !isMuted else { return }
        let data = soundData(key: "sfx:clear", asset: "sfx_stage_clear") {
            SynthAudio.generateStageClearSFX(durationSeconds: 1.2)
        }
        playOneShot(data: data, volume: sfxVolume)
    }

    func playStageFail() {
        guard !isMuted else { return }
        let data = soundData(key: "sfx:fail", asset: "sfx_stage_fail") {
            SynthAudio.generateStageFailSFX(durationSeconds: 0.8)
        }
        playOneShot(data: data, volume: sfxVolume * 0.7)
    }

    /// Brief low-frequency thump for terrain/obstacle brushes. Distinct
    /// from `playStageFail` (which is the bigger "mission lost" cue) — this
    /// is more of a physical "ouch, that hurt" beat to pair with the
    /// heavy-haptic generator on `MissionEngine.registerCollision()`.
    func playCollision() {
        guard !isMuted else { return }
        let data = soundData(key: "sfx:collision", asset: "sfx_collision") {
            SynthAudio.generateCollisionSFX(durationSeconds: 0.25)
        }
        playOneShot(data: data, volume: sfxVolume * 0.6)
    }

    /// Single high-pitched chirp used for the 5/3/1-second mission-timer
    /// countdown. Distinct from `playButtonTap` (which is a flatter UI
    /// click) — this rises slightly so consecutive ticks feel urgent.
    func playTimerTick() {
        guard !isMuted else { return }
        let data = soundData(key: "sfx:tick", asset: "sfx_timer_tick") {
            SynthAudio.generateTimerTickSFX(durationSeconds: 0.18)
        }
        playOneShot(data: data, volume: sfxVolume * 0.55)
    }

    func playButtonTap() {
        guard !isMuted else { return }
        let data = soundData(key: "sfx:tap", asset: "sfx_button_tap") {
            SynthAudio.generateButtonTapSFX(durationSeconds: 0.1)
        }
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

    /// Hard cap on simultaneous one-shot retains. Without this, a rapid
    /// flurry of pickups (multi-star cluster + ring pass on the same
    /// frame) could push the sfxPlayers dictionary past a few dozen
    /// entries if any asyncAfter scheduler hiccups. 24 covers the
    /// worst observed burst (~6 stars + 1 ring + UI taps) with a 4×
    /// safety margin while keeping the audio mixer's voice budget
    /// healthy.
    private static let maxConcurrentOneShots = 24

    private func playOneShot(data: Data, volume: Float) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let player = try AVAudioPlayer(data: data)
                player.volume = volume
                player.numberOfLoops = 0
                player.prepareToPlay()
                player.play()
                let key = UUID().uuidString
                // AVAudioPlayer.duration can occasionally read as 0 on
                // freshly-prepared synth payloads — fall back to a 2s
                // worst-case window so a 0-duration read can't leak the
                // entry. The +0.1s buffer past `duration` matches the
                // original code path for the well-behaved case.
                let cleanupDelay: TimeInterval = player.duration > 0
                    ? player.duration + 0.1
                    : 2.0
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // Hard cap defense — if the dictionary grew past the
                    // budget (asyncAfter scheduler hiccup, etc.), drop
                    // the oldest entries before inserting the new one
                    // so we never accumulate beyond `maxConcurrentOneShots`.
                    if self.sfxPlayers.count >= Self.maxConcurrentOneShots {
                        let overflow = self.sfxPlayers.count - Self.maxConcurrentOneShots + 1
                        for k in self.sfxPlayers.keys.prefix(overflow) {
                            self.sfxPlayers[k]?.stop()
                            self.sfxPlayers.removeValue(forKey: k)
                        }
                    }
                    self.sfxPlayers[key] = player
                    DispatchQueue.main.asyncAfter(deadline: .now() + cleanupDelay) { [weak self] in
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

    /// Procedural BGM, Phase 4 version. The previous loop was a single
    /// static chord with a 30-second swell — pleasant for a demo and
    /// fatiguing by the third run. This one is a four-bar progression
    /// (I–vi–IV–V flavoured per theme) with a soft triangle-ish pad, a
    /// gently pulsing arpeggio on top, and a filtered-noise "wind" bed,
    /// looping seamlessly at `durationSeconds`. Still zero assets; a
    /// bundled `bgm_<theme>.m4a` overrides it (see `AudioManager.assetURL`).
    static func generateBGM(theme: String, durationSeconds: Double) -> Data {
        let numSamples = Int(sampleRate * durationSeconds)
        var samples = [Int16](repeating: 0, count: numSamples)

        // Chord roots (Hz) for four bars, each a triad built on the root.
        let progression: [Double]
        let arpRate: Double          // notes per second
        let windLevel: Double
        switch theme {
        case "space":
            progression = [130.81, 110.0, 174.61, 196.0]   // C3 A2 F3 G3 — wide, slow
            arpRate = 3
            windLevel = 0.05
        case "ocean":
            progression = [146.83, 123.47, 196.0, 220.0]   // D3 B2 G3 A3 — flowing
            arpRate = 4
            windLevel = 0.08
        default: // sky
            progression = [196.0, 164.81, 261.63, 293.66]  // G3 E3 C4 D4 — bright
            arpRate = 5
            windLevel = 0.06
        }
        let barSeconds = durationSeconds / Double(progression.count)
        let major: [Double] = [1.0, 1.25, 1.5, 2.0]       // root, 3rd, 5th, octave
        var noiseState = 0.0

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let bar = min(Int(t / barSeconds), progression.count - 1)
            let root = progression[bar]
            let barT = t - Double(bar) * barSeconds
            // Cross-fade chords over the last 0.4s of each bar so changes
            // don't click.
            let fade = min(1.0, barT / 0.15) * min(1.0, (barSeconds - barT) / 0.4 + 0.6)

            var sample = 0.0
            // Pad: sum of triangle-ish partials (odd harmonics rolled off).
            for (k, ratio) in major.enumerated() {
                let f = root * ratio
                let base = sin(2.0 * .pi * f * t)
                let third = sin(2.0 * .pi * f * 3 * t) / 9.0
                let lfo = 0.85 + 0.15 * sin(t * 0.5 + Double(k))
                sample += (base + third) * 0.09 * lfo
            }
            // Arpeggio: one note at a time, plucked envelope.
            let step = Int(t * arpRate)
            let noteRatio = major[step % major.count] * 2.0
            let noteStart = Double(step) / arpRate
            let pluckEnv = exp(-(t - noteStart) * 6.0)
            sample += sin(2.0 * .pi * root * noteRatio * t) * pluckEnv * 0.10
            // Wind bed: one-pole low-passed noise, slowly breathing.
            noiseState += (Double.random(in: -1...1) - noiseState) * 0.02
            sample += noiseState * windLevel * (0.6 + 0.4 * sin(t * 0.25))

            // Loop-safe edges.
            let edge = min(1.0, t / 0.5, (durationSeconds - t) / 0.5)
            samples[i] = Int16(clamping: Int(sample * fade * edge * 14000))
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
