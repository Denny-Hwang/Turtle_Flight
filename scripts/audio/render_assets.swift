// Offline renderer for the game's bundled audio: one music loop per
// world, one engine loop per vehicle, and the one-shot sound effects.
//
//   bash scripts/audio/build_audio.sh        # renders + encodes into TurtleFlight/Audio/
//
// Everything is synthesised here from first principles (plucked strings,
// FM bells, breathy flutes, soft pads, hand drums) — no samples, no
// generative models, no third-party audio — so the files carry no
// licence beyond this repository's. The output is deterministic: the
// same script renders the same bytes.
//
// `AudioManager.assetURL` picks the files up by name (`bgm_<world>`,
// `vehicle_<sound>`, `sfx_<event>`); anything missing falls back to the
// in-app synthesiser.

import Foundation

let sr = 44_100.0
let twoPi = 2.0 * Double.pi

// MARK: - Small DSP kit

struct Rng {
    var s: UInt64
    init(_ seed: UInt64) { s = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        s &+= 0x9E37_79B9_7F4A_7C15
        var z = s
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func signed() -> Double { unit() * 2 - 1 }
    mutating func int(_ n: Int) -> Int { Int(next() % UInt64(n)) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
}

func mtof(_ m: Double) -> Double { 440 * pow(2, (m - 69) / 12) }

/// Stereo buffer that notes are mixed into.
final class Mix {
    var l: [Double]
    var r: [Double]
    init(samples: Int) { l = .init(repeating: 0, count: samples); r = l }
    var count: Int { l.count }

    func add(_ mono: [Double], at start: Int, gain: Double, pan: Double = 0) {
        // Equal-power pan, -1 … 1.
        let a = (pan + 1) * .pi / 4
        let gl = cos(a) * gain, gr = sin(a) * gain
        for (i, v) in mono.enumerated() {
            let j = start + i
            guard j >= 0, j < l.count else { continue }
            l[j] += v * gl
            r[j] += v * gr
        }
    }
}

/// Attack / release envelope on top of a decay curve.
func shaped(_ n: Int, attack: Double, release: Double, _ body: (Int, Double) -> Double) -> [Double] {
    let a = max(1, Int(attack * sr)), rel = max(1, Int(release * sr))
    return (0..<n).map { i in
        let t = Double(i) / sr
        var env = 1.0
        if i < a { env = Double(i) / Double(a) }
        if i > n - rel { env *= Double(n - i) / Double(rel) }
        return body(i, t) * env
    }
}

// MARK: - Instruments

/// Karplus–Strong plucked string. `bright` 0…1, `sustain` sets decay.
func pluck(_ f: Double, _ dur: Double, bright: Double = 0.5, sustain: Double = 0.996, seed: UInt64 = 1) -> [Double] {
    var rng = Rng(seed &+ UInt64(f * 100))
    let period = max(2, Int(sr / f))
    var buf = (0..<period).map { _ in rng.signed() }
    // Soften the initial burst for darker strings.
    for _ in 0..<Int((1 - bright) * 4) {
        buf = (0..<period).map { (buf[$0] + buf[($0 + 1) % period]) / 2 }
    }
    let n = Int(dur * sr)
    var out = [Double](repeating: 0, count: n)
    var idx = 0
    for i in 0..<n {
        let a = buf[idx], b = buf[(idx + 1) % period]
        let v = sustain * (a * (0.5 + bright * 0.25) + b * (0.5 - bright * 0.25))
        buf[idx] = v
        out[i] = a
        idx = (idx + 1) % period
    }
    let rel = min(n, Int(0.05 * sr))
    for i in 0..<rel { out[n - 1 - i] *= Double(i) / Double(rel) }
    return out
}

/// Soft mallet: fundamental + a quiet 4th partial, quick decay.
func marimba(_ f: Double, _ dur: Double) -> [Double] {
    shaped(Int(dur * sr), attack: 0.002, release: 0.05) { _, t in
        let e = exp(-t * 5.5)
        return (sin(twoPi * f * t) + 0.28 * sin(twoPi * f * 3.98 * t) * exp(-t * 18)) * e
    }
}

/// FM bell: inharmonic, glassy, long ring.
func bell(_ f: Double, _ dur: Double, ratio: Double = 3.5) -> [Double] {
    shaped(Int(dur * sr), attack: 0.002, release: 0.2) { _, t in
        let index = 3.2 * exp(-t * 2.5)
        return sin(twoPi * f * t + index * sin(twoPi * f * ratio * t)) * exp(-t * 1.6)
    }
}

/// Breathy flute with delayed vibrato.
func flute(_ f: Double, _ dur: Double, seed: UInt64 = 3) -> [Double] {
    var rng = Rng(seed)
    var breath = 0.0
    return shaped(Int(dur * sr), attack: 0.07, release: 0.12) { _, t in
        let vib = 1 + 0.006 * sin(twoPi * 5.2 * t) * min(1, max(0, (t - 0.18) * 3))
        breath += (rng.signed() - breath) * 0.08
        let ph = twoPi * f * vib * t
        return (sin(ph) + 0.18 * sin(2 * ph) + 0.06 * sin(3 * ph)) * 0.85 + breath * 0.12
    }
}

/// Detuned, low-passed saw pad with a slow swell.
func pad(_ freqs: [Double], _ dur: Double, cutoff: Double = 1400, attack: Double = 0.9) -> [Double] {
    let n = Int(dur * sr)
    var out = [Double](repeating: 0, count: n)
    let k = 1 - exp(-twoPi * cutoff / sr)
    for (vi, f) in freqs.enumerated() {
        for detune in [-0.0035, 0.0, 0.0041] {
            let ff = f * (1 + detune)
            var phase = Double(vi) * 0.31 + detune * 100
            var lp = 0.0
            for i in 0..<n {
                phase += ff / sr
                phase -= floor(phase)
                lp += (2 * phase - 1 - lp) * k
                out[i] += lp
            }
        }
    }
    let norm = 1 / Double(max(1, freqs.count * 3))
    let a = Int(attack * sr), rel = Int(min(1.2, dur * 0.4) * sr)
    for i in 0..<n {
        var env = 1.0
        if i < a { env = Double(i) / Double(a) }
        if i > n - rel { env *= Double(n - i) / Double(rel) }
        out[i] *= env * norm
    }
    return out
}

/// Accordion-ish reed: odd harmonics, two detuned reeds, bellows tremolo.
func reed(_ f: Double, _ dur: Double) -> [Double] {
    shaped(Int(dur * sr), attack: 0.03, release: 0.08) { _, t in
        var v = 0.0
        for (h, amp) in [(1.0, 1.0), (2.0, 0.45), (3.0, 0.35), (4.0, 0.15), (5.0, 0.12)] {
            v += amp * (sin(twoPi * f * h * t) + sin(twoPi * f * 1.004 * h * t)) * 0.5
        }
        return v * 0.45 * (0.88 + 0.12 * sin(twoPi * 5.5 * t))
    }
}

func bass(_ f: Double, _ dur: Double) -> [Double] {
    shaped(Int(dur * sr), attack: 0.006, release: 0.06) { _, t in
        let v = sin(twoPi * f * t) + 0.35 * sin(twoPi * 2 * f * t)
        return tanh(v * 1.3) * (0.75 + 0.25 * exp(-t * 6))
    }
}

func kick(_ gain: Double = 1) -> [Double] {
    var phase = 0.0
    return (0..<Int(0.35 * sr)).map { i in
        let t = Double(i) / sr
        let f = 45 + 80 * exp(-t * 28)
        phase += twoPi * f / sr
        return sin(phase) * exp(-t * 11) * gain
    }
}

func shaker(_ seed: UInt64, _ gain: Double = 1) -> [Double] {
    var rng = Rng(seed)
    var prev = 0.0
    return (0..<Int(0.07 * sr)).map { i in
        let t = Double(i) / sr
        let n = rng.signed()
        let hp = n - prev
        prev = n
        return hp * 0.5 * min(1, t * 300) * exp(-t * 55) * gain
    }
}

/// Hand drum: `low` = deep open stroke, otherwise a bright slap.
func handDrum(low: Bool, seed: UInt64) -> [Double] {
    var rng = Rng(seed)
    var phase = 0.0
    var lp = 0.0
    return (0..<Int((low ? 0.45 : 0.12) * sr)).map { i in
        let t = Double(i) / sr
        let f = low ? 82 + 50 * exp(-t * 30) : 330 + 120 * exp(-t * 60)
        phase += twoPi * f / sr
        lp += (rng.signed() - lp) * (low ? 0.05 : 0.5)
        let tone = sin(phase) * exp(-t * (low ? 7 : 30))
        let skin = lp * exp(-t * (low ? 40 : 45)) * (low ? 0.6 : 1.4)
        return (tone + skin) * (low ? 0.9 : 0.55)
    }
}

func tom(_ f: Double) -> [Double] {
    var phase = 0.0
    return (0..<Int(0.5 * sr)).map { i in
        let t = Double(i) / sr
        phase += twoPi * (f + f * 0.4 * exp(-t * 20)) / sr
        return sin(phase) * exp(-t * 6)
    }
}

// MARK: - Effects

/// Small stereo room (Freeverb-style: parallel combs into allpasses).
func reverb(_ mix: Mix, wet: Double, size: Double = 0.80, damp: Double = 0.35) {
    func process(_ input: [Double], spread: Int) -> [Double] {
        let combs = [1116, 1188, 1277, 1356, 1422, 1491].map { $0 + spread }
        let allpasses = [556, 441, 341].map { $0 + spread }
        var out = [Double](repeating: 0, count: input.count)
        for d in combs {
            var buf = [Double](repeating: 0, count: d)
            var idx = 0, store = 0.0
            for i in 0..<input.count {
                let y = buf[idx]
                store = y * (1 - damp) + store * damp
                buf[idx] = input[i] * 0.015 + store * size
                out[i] += y
                idx = (idx + 1) % d
            }
        }
        for d in allpasses {
            var buf = [Double](repeating: 0, count: d)
            var idx = 0
            for i in 0..<out.count {
                let b = buf[idx]
                let y = -out[i] + b
                buf[idx] = out[i] + b * 0.5
                out[i] = y
                idx = (idx + 1) % d
            }
        }
        return out
    }
    let wl = process(mix.l, spread: 0)
    let wr = process(mix.r, spread: 23)
    for i in 0..<mix.count {
        mix.l[i] += wl[i] * wet
        mix.r[i] += wr[i] * wet
    }
}

/// Ping-pong echo.
func echo(_ mix: Mix, seconds: Double, feedback: Double, wet: Double) {
    let d = Int(seconds * sr)
    guard d > 0, d < mix.count else { return }
    var el = [Double](repeating: 0, count: mix.count), er = el
    for i in d..<mix.count {
        el[i] = (mix.r[i - d] + er[i - d] * feedback)
        er[i] = (mix.l[i - d] + el[i - d] * feedback) * 0.9
    }
    for i in 0..<mix.count {
        mix.l[i] += el[i] * wet
        mix.r[i] += er[i] * wet
    }
}

/// Fold everything past `length` back onto the start so the loop point
/// is seamless (reverb tails and long notes ring into the next pass).
func fold(_ mix: Mix, length: Int) -> Mix {
    let out = Mix(samples: length)
    for i in 0..<mix.count {
        out.l[i % length] += mix.l[i]
        out.r[i % length] += mix.r[i]
    }
    return out
}

func normalize(_ mix: Mix, peak: Double) {
    var m = 1e-9
    for i in 0..<mix.count { m = max(m, abs(mix.l[i]), abs(mix.r[i])) }
    let g = peak / m
    for i in 0..<mix.count {
        // Gentle soft clip after gain, in case of a stray transient.
        mix.l[i] = tanh(mix.l[i] * g * 1.1) / tanh(1.1)
        mix.r[i] = tanh(mix.r[i] * g * 1.1) / tanh(1.1)
    }
}

// MARK: - WAV out

func writeWav(_ path: String, left: [Double], right: [Double]?) {
    let channels = right == nil ? 1 : 2
    var data = Data()
    func u32(_ v: UInt32) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 4)) }
    func u16(_ v: UInt16) { var x = v.littleEndian; data.append(Data(bytes: &x, count: 2)) }
    let frames = left.count
    let bytes = frames * channels * 2
    data.append("RIFF".data(using: .ascii)!); u32(UInt32(36 + bytes))
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!); u32(16); u16(1); u16(UInt16(channels))
    u32(UInt32(sr)); u32(UInt32(sr) * UInt32(channels) * 2); u16(UInt16(channels * 2)); u16(16)
    data.append("data".data(using: .ascii)!); u32(UInt32(bytes))
    data.reserveCapacity(44 + bytes)
    for i in 0..<frames {
        u16(UInt16(bitPattern: Int16(max(-1, min(1, left[i])) * 32_000)))
        if let right { u16(UInt16(bitPattern: Int16(max(-1, min(1, right[i])) * 32_000))) }
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

// MARK: - Songwriting

/// One world's tune: a progression, a scale, a groove and a band.
struct Song {
    enum Lead { case marimba, pluck, reed, gayageum, flute, bell }
    enum Groove { case pop, darbuka, waltz, janggu, tribal, none, tide }

    let name: String
    let bpm: Double
    let beatsPerBar: Int
    /// Scale as semitones above `root`.
    let scale: [Int]
    let root: Int
    /// One chord per bar (MIDI notes), 8 bars; the tune plays them `reps` times.
    let chords: [[Int]]
    let reps: Int
    let lead: Lead
    let counter: Lead?
    let groove: Groove
    let arp: Bool
    let padCutoff: Double
    let reverbWet: Double
    let echoWet: Double
    /// Notes per beat the melody moves in (1 = crotchets, 2 = quavers).
    let density: Double
    let seed: UInt64
}

/// Scale-degree melody that leans on chord tones on strong beats and
/// steps between them, with a two-bar motif repeated and varied.
func melody(for song: Song, rep: Int) -> [(beat: Double, len: Double, midi: Int)] {
    var rng = Rng(song.seed &+ UInt64(rep * 7919))
    // All scale notes across three octaves around the root.
    var scaleNotes: [Int] = []
    for octave in -1...2 {
        for s in song.scale { scaleNotes.append(song.root + octave * 12 + s) }
    }
    scaleNotes.sort()
    let low = song.root - 3, high = song.root + 16
    let usable = scaleNotes.filter { $0 >= low && $0 <= high }

    func nearest(_ target: Int, in set: [Int]) -> Int {
        set.min { abs($0 - target) < abs($1 - target) } ?? target
    }

    let bpb = Double(song.beatsPerBar)
    // Rhythm cells, in beats, that fill one bar.
    let cells: [[Double]] = song.beatsPerBar == 3
        ? [[1, 1, 1], [2, 1], [1.5, 0.5, 1], [3]]
        : (song.density >= 2
            ? [[1, 0.5, 0.5, 1, 1], [0.5, 0.5, 1, 0.5, 0.5, 1], [1.5, 0.5, 2], [1, 1, 0.5, 0.5, 1], [2, 1, 1]]
            : [[2, 2], [1, 1, 2], [3, 1], [4], [1.5, 0.5, 2]])

    var notes: [(Double, Double, Int)] = []
    var prev = song.root + 4
    var motif: [(Double, Double, Int)] = []   // two bars, relative to bar start
    for bar in 0..<song.chords.count {
        let chord = song.chords[bar]
        let chordTones = usable.filter { n in chord.contains { ($0 - n) % 12 == 0 } }
        let start = Double(bar) * bpb
        // Bars 2–3 repeat bars 0–1 snapped onto the new chords; the last
        // bar resolves to a long chord tone.
        if bar == 2 || bar == 3, !motif.isEmpty {
            for (b, len, m) in motif where (bar == 2 ? b < bpb : b >= bpb) {
                let rel = bar == 2 ? b : b - bpb
                let onBeat = rel.truncatingRemainder(dividingBy: 1) == 0
                let shifted = nearest(m + (rep % 2 == 1 ? 0 : 2), in: onBeat ? chordTones : usable)
                notes.append((start + rel, len, shifted))
                prev = shifted
            }
            continue
        }
        if bar == song.chords.count - 1 {
            let target = nearest(song.root + (rep % 2 == 0 ? 0 : 12), in: chordTones.isEmpty ? usable : chordTones)
            notes.append((start, bpb * 0.75, target))
            prev = target
            continue
        }
        var cell = cells[rng.int(cells.count)]
        if bar % 2 == 1 && rng.chance(0.3) { cell = cells[0] }
        var b = 0.0
        for len in cell {
            // Rests now and then so the line breathes.
            if b > 0 && rng.chance(0.12) { b += len; continue }
            let strong = b.truncatingRemainder(dividingBy: 2) == 0 || b == 0
            var next: Int
            if strong || chordTones.isEmpty == false && rng.chance(0.35) {
                let options = chordTones.filter { abs($0 - prev) <= 7 }
                next = options.isEmpty ? nearest(prev, in: chordTones) : options[rng.int(options.count)]
            } else {
                let i = usable.firstIndex(of: nearest(prev, in: usable)) ?? 0
                let step = rng.chance(0.5) ? 1 : -1
                let leap = rng.chance(0.15) ? 2 : 1
                next = usable[max(0, min(usable.count - 1, i + step * leap))]
            }
            notes.append((start + b, len, next))
            if bar < 2 { motif.append((Double(bar) * bpb + b, len, next)) }
            prev = next
            b += len
        }
    }
    return notes
}

func render(_ song: Song) -> Mix {
    let beat = 60 / song.bpm
    let bars = song.chords.count * song.reps
    let loopBeats = Double(bars * song.beatsPerBar)
    let loopLen = Int(loopBeats * beat * sr)
    let mix = Mix(samples: loopLen + Int(4 * sr))
    var rng = Rng(song.seed &* 31)
    func at(_ b: Double) -> Int { Int(b * beat * sr) }
    let bpb = Double(song.beatsPerBar)

    func play(_ lead: Song.Lead, midi: Int, beat b: Double, len: Double, gain: Double, pan: Double) {
        let f = mtof(Double(midi))
        let d = len * beat
        let v: [Double]
        switch lead {
        case .marimba:  v = marimba(f, max(0.6, d + 0.4))
        case .pluck:    v = pluck(f, max(0.8, d + 0.6), bright: 0.65, sustain: 0.995, seed: UInt64(midi))
        case .gayageum: v = pluck(f, max(1.2, d + 1.0), bright: 0.45, sustain: 0.9985, seed: UInt64(midi) &+ 9)
        case .reed:     v = reed(f, d * 0.95)
        case .flute:    v = flute(f, d * 0.98, seed: UInt64(midi))
        case .bell:     v = bell(f, max(1.5, d + 1.5))
        }
        mix.add(v, at: at(b), gain: gain, pan: pan)
    }

    for rep in 0..<song.reps {
        let repStart = Double(rep * song.chords.count) * bpb
        // Chords: pad + bass.
        for (bar, chord) in song.chords.enumerated() {
            let b0 = repStart + Double(bar) * bpb
            mix.add(pad(chord.map { mtof(Double($0)) }, bpb * beat + 0.6, cutoff: song.padCutoff),
                    at: at(b0), gain: 0.22, pan: 0)
            let rootNote = chord[0] - 24
            switch song.groove {
            case .waltz:
                // Oom-pah-pah.
                mix.add(bass(mtof(Double(rootNote)), beat * 0.9), at: at(b0), gain: 0.30)
                for k in 1...2 {
                    for (j, n) in chord.enumerated() {
                        mix.add(pluck(mtof(Double(n)), beat * 0.6, bright: 0.4, sustain: 0.99, seed: UInt64(n + k)),
                                at: at(b0 + Double(k)), gain: 0.07, pan: Double(j - 1) * 0.3)
                    }
                }
            case .none, .tide:
                mix.add(bass(mtof(Double(rootNote)), bpb * beat * 0.95), at: at(b0), gain: 0.18)
            default:
                mix.add(bass(mtof(Double(rootNote)), beat * 1.8), at: at(b0), gain: 0.26)
                mix.add(bass(mtof(Double(rootNote + (rng.chance(0.5) ? 7 : 12))), beat * 1.6),
                        at: at(b0 + 2), gain: 0.2)
            }
            // Arpeggio: chord tones climbing in quavers.
            if song.arp {
                let tones = chord + chord.map { $0 + 12 }
                let steps = Int(bpb * 2)
                for s in 0..<steps {
                    let n = tones[(s + bar) % tones.count]
                    let lead: Song.Lead = song.lead == .gayageum ? .gayageum : .pluck
                    play(lead, midi: n, beat: b0 + Double(s) * 0.5, len: 0.5,
                         gain: 0.06 + (s % 2 == 0 ? 0.015 : 0), pan: s % 2 == 0 ? -0.45 : 0.45)
                }
            }
            // Groove.
            for s in 0..<Int(bpb * 2) {
                let b = b0 + Double(s) * 0.5
                let seed = UInt64(rep * 1000 + bar * 10 + s)
                switch song.groove {
                case .pop:
                    if s == 0 || s == 4 { mix.add(kick(), at: at(b), gain: 0.32) }
                    mix.add(shaker(seed), at: at(b), gain: s % 2 == 1 ? 0.12 : 0.07, pan: 0.3)
                case .darbuka:
                    // doum . tek . doum doum tek .
                    let pattern: [Int: Bool] = [0: true, 2: false, 4: true, 5: true, 6: false]
                    if let low = pattern[s] { mix.add(handDrum(low: low, seed: seed), at: at(b), gain: 0.30, pan: low ? -0.1 : 0.2) }
                    if s % 2 == 1 && s != 5 { mix.add(shaker(seed), at: at(b), gain: 0.06, pan: 0.4) }
                case .waltz:
                    if s == 2 || s == 4 { mix.add(shaker(seed), at: at(b), gain: 0.07, pan: 0.3) }
                case .janggu:
                    // A lilting 12/8-ish feel: deep on 1, light taps after.
                    if s == 0 { mix.add(handDrum(low: true, seed: seed), at: at(b), gain: 0.26, pan: -0.2) }
                    if s == 3 || s == 5 || s == 6 { mix.add(handDrum(low: false, seed: seed), at: at(b), gain: 0.14, pan: 0.25) }
                case .tribal:
                    if s == 0 || s == 3 || s == 4 { mix.add(tom(s == 3 ? 130 : 95), at: at(b), gain: 0.30, pan: s == 3 ? 0.3 : -0.2) }
                    mix.add(shaker(seed), at: at(b), gain: 0.08, pan: 0.35)
                case .tide:
                    break
                case .none:
                    break
                }
            }
        }
        // Lead melody (and the counter line on the second pass).
        for (b, len, m) in melody(for: song, rep: rep) {
            play(song.lead, midi: m, beat: repStart + b, len: len, gain: 0.26, pan: -0.1)
            if rep % 2 == 1, let counter = song.counter {
                play(counter, midi: m + (counter == .bell ? 12 : 0), beat: repStart + b + (counter == .bell ? 0.5 : 0),
                     len: len, gain: 0.12, pan: 0.35)
            }
        }
    }
    if song.groove == .tide {
        // Waves: slow swells of filtered noise.
        var r2 = Rng(song.seed)
        var lp = 0.0
        let wave = (0..<mix.count).map { i -> Double in
            let t = Double(i) / sr
            lp += (r2.signed() - lp) * 0.02
            return lp * (0.5 + 0.5 * sin(twoPi * t / 7.5)) * 1.6
        }
        mix.add(wave, at: 0, gain: 0.25)
    }
    if song.echoWet > 0 { echo(mix, seconds: beat * 0.75, feedback: 0.45, wet: song.echoWet) }
    reverb(mix, wet: song.reverbWet)
    let looped = fold(mix, length: loopLen)
    // Music sits under the effects: about -7 dBFS peak, like the old synth.
    normalize(looped, peak: 0.45)
    return looped
}

// Chords are written as MIDI note lists, one per bar.
let C = 60, D = 62, E = 64, F = 65, G = 67, A = 69, B = 71
let songs: [Song] = [
    Song(name: "sky", bpm: 100, beatsPerBar: 4, scale: [0, 2, 4, 5, 7, 9, 11], root: C,
         chords: [[C, E, G], [G - 12, B - 12, D], [A - 12, C, E], [F - 12, A - 12, C],
                  [C, E, G], [G - 12, B - 12, D], [F - 12, A - 12, C], [G - 12, B - 12, D]],
         reps: 2, lead: .marimba, counter: .bell, groove: .pop, arp: true,
         padCutoff: 1500, reverbWet: 0.9, echoWet: 0, density: 2, seed: 11),
    Song(name: "desert", bpm: 92, beatsPerBar: 4, scale: [0, 1, 4, 5, 7, 8, 10], root: D,
         chords: [[D, F + 1, A], [D + 1, G, A + 1], [D, F + 1, A], [C, D + 1, G],
                  [D, F + 1, A], [D + 1, G, A + 1], [G - 12, A + 1 - 12, D], [D, F + 1, A]],
         reps: 2, lead: .pluck, counter: .flute, groove: .darbuka, arp: false,
         padCutoff: 900, reverbWet: 1.0, echoWet: 0.18, density: 2, seed: 23),
    Song(name: "city", bpm: 138, beatsPerBar: 3, scale: [0, 2, 4, 5, 7, 9, 10, 11], root: F,
         chords: [[F, A, C + 12, E + 12], [D, F, A, C + 12], [G - 12, A + 1 - 12, D, F], [C, E, G, A + 1],
                  [F, A, C + 12, E + 12], [A - 12, C, E, G], [A + 1 - 12, D, F, A], [C, E, G, A + 1]],
         reps: 4, lead: .reed, counter: .marimba, groove: .waltz, arp: false,
         padCutoff: 1100, reverbWet: 0.8, echoWet: 0, density: 1, seed: 37),
    Song(name: "seoul", bpm: 84, beatsPerBar: 4, scale: [0, 2, 4, 7, 9], root: G - 12,
         chords: [[G - 12, B - 12, D], [E - 12, G - 12, B - 12], [C, E, G], [D, A, D + 12],
                  [G - 12, B - 12, D], [E - 12, G - 12, B - 12], [A - 12, C, E], [D, G, A]],
         reps: 2, lead: .gayageum, counter: .flute, groove: .janggu, arp: false,
         padCutoff: 1000, reverbWet: 1.1, echoWet: 0.15, density: 2, seed: 41),
    Song(name: "wild", bpm: 104, beatsPerBar: 4, scale: [0, 2, 3, 5, 7, 9, 10], root: A - 12,
         chords: [[A - 12, E, A], [G - 12, D, G], [A - 12, E, A], [D, A, D + 12],
                  [A - 12, E, A], [C, G, C + 12], [G - 12, D, G], [E - 12, B - 12, E]],
         reps: 2, lead: .flute, counter: .pluck, groove: .tribal, arp: true,
         padCutoff: 1200, reverbWet: 1.1, echoWet: 0.1, density: 2, seed: 53),
    Song(name: "space", bpm: 72, beatsPerBar: 4, scale: [0, 2, 4, 6, 7, 9, 11], root: E,
         chords: [[E - 12, G + 1 - 12, B - 12, D + 1], [F + 1 - 12, A + 1 - 12, C + 1], [C + 1 - 12, E - 12, G + 1 - 12, B - 12], [B - 24, D + 1 - 12, F + 1 - 12, A - 12 + 2],
                  [E - 12, G + 1 - 12, B - 12, D + 1], [F + 1 - 12, A + 1 - 12, C + 1], [A - 12, C + 1, E], [B - 24, D + 1 - 12, F + 1 - 12]],
         reps: 2, lead: .bell, counter: .bell, groove: .none, arp: true,
         padCutoff: 900, reverbWet: 1.6, echoWet: 0.35, density: 1, seed: 67),
    Song(name: "ocean", bpm: 80, beatsPerBar: 4, scale: [0, 2, 4, 5, 7, 9, 11], root: D,
         chords: [[D, F + 1, A, C + 1 + 12], [B - 12, D, F + 1, A], [G - 12, B - 12, D, F + 1], [A - 12, C + 1, E],
                  [D, F + 1, A, C + 1 + 12], [F + 1 - 12, A - 12, C + 1, E], [G - 12, B - 12, D, F + 1], [A - 12, C + 1, E, G]],
         reps: 2, lead: .bell, counter: .flute, groove: .tide, arp: true,
         padCutoff: 800, reverbWet: 1.4, echoWet: 0.25, density: 1, seed: 79),
]

// MARK: - Vehicle loops (4 s, seamless)

func vehicleLoop(_ name: String) -> [Double] {
    let n = Int(4 * sr)
    var rng = Rng(UInt64(truncatingIfNeeded: name.utf8.reduce(7) { $0 &* 31 &+ Int($1) }))
    var out = [Double](repeating: 0, count: n)
    var lp1 = 0.0, lp2 = 0.0, bp = 0.0
    for i in 0..<n {
        let t = Double(i) / sr
        // Loop-safe LFOs: whole cycles in 4 s.
        let slow = sin(twoPi * t / 4)
        let mid = sin(twoPi * t / 2)
        let noise = rng.signed()
        lp1 += (noise - lp1) * 0.04
        lp2 += (noise - lp2) * 0.25
        bp = lp2 - lp1
        var v = 0.0
        switch name {
        case "jet_whoosh":
            v = sin(twoPi * 55 * t) * 0.35 + sin(twoPi * 110.5 * t) * 0.12 + bp * 0.9 * (0.8 + 0.2 * slow) + lp1 * 1.2
        case "jet_whoosh_soft":
            v = sin(twoPi * 70 * t) * 0.18 + bp * 0.5 * (0.8 + 0.2 * mid) + lp1 * 0.9
        case "glide_wind":
            v = lp1 * 2.2 * (0.6 + 0.4 * slow) + bp * 0.35 * (0.5 + 0.5 * mid)
        case "copter_spin":
            // 12 rotor beats a second (48 in the loop) over a soft whirr.
            let beat = (t * 12).truncatingRemainder(dividingBy: 1)
            v = exp(-beat * 9) * (sin(twoPi * 70 * t) * 0.6 + lp2 * 0.5) + bp * 0.25 + sin(twoPi * 220 * t) * 0.04
        case "balloon_hiss":
            v = bp * 0.6 * (0.7 + 0.3 * slow) + sin(twoPi * (330 + 6 * mid) * t) * 0.05
        case "balloon_inflate":
            // Rubbery creak: a wobbling low tone under breathy air.
            v = sin(twoPi * (95 + 12 * sin(twoPi * t * 1.5)) * t) * 0.22 + lp1 * 1.3 * (0.7 + 0.3 * mid)
        case "cloud_whoosh":
            v = lp1 * 1.8 * (0.65 + 0.35 * slow) + bp * 0.2 + sin(twoPi * 440 * t) * 0.01 * (1 + mid)
        default:
            v = lp1
        }
        out[i] = v
    }
    // Cross-fade the last 50 ms into the first so the wrap is click-free.
    let xf = Int(0.05 * sr)
    for i in 0..<xf {
        let a = Double(i) / Double(xf)
        out[i] = out[i] * a + out[n - xf + i] * (1 - a)
    }
    let trimmed = Array(out[0..<(n - xf)])
    let peak = trimmed.map(abs).max() ?? 1
    return trimmed.map { $0 / peak * 0.45 }
}

// MARK: - Sound effects

func sfx(_ name: String) -> [Double] {
    func seconds(_ s: Double) -> Int { Int(s * sr) }
    var out: [Double]
    switch name {
    case "star_collect":
        // Two bright chimes, a fifth apart.
        out = [Double](repeating: 0, count: seconds(0.55))
        for (k, f) in [1318.5, 1975.5].enumerated() {
            let v = bell(f, 0.45, ratio: 2.0)
            for (i, x) in v.enumerated() where i + k * seconds(0.07) < out.count { out[i + k * seconds(0.07)] += x * 0.5 }
        }
    case "ring_pass":
        var rng = Rng(5)
        var lp = 0.0
        out = (0..<seconds(0.5)).map { i in
            let t = Double(i) / sr
            lp += (rng.signed() - lp) * (0.05 + 0.4 * t)
            let whoosh = lp * sin(.pi * min(1, t / 0.35)) * 1.6
            let chime = sin(twoPi * 1046.5 * t + 1.5 * sin(twoPi * 2093 * t) * exp(-t * 8)) * exp(-t * 7) * (t > 0.06 ? 0.4 : 0)
            return whoosh + chime
        }
    case "boost":
        var rng = Rng(9)
        var lp = 0.0
        var phase = 0.0
        out = (0..<seconds(0.9)).map { i in
            let t = Double(i) / sr
            let k = 0.03 + 0.25 * min(1, t / 0.6)
            lp += (rng.signed() - lp) * k
            phase += twoPi * (180 + 520 * min(1, t / 0.6)) / sr
            let env = min(1, t / 0.08) * exp(-max(0, t - 0.5) * 6)
            return (lp * 1.4 + sin(phase) * 0.25) * env
        }
    case "stage_clear":
        // Rising arpeggio into a held major chord.
        out = [Double](repeating: 0, count: seconds(1.8))
        let notes = [72, 76, 79, 84]
        for (k, m) in notes.enumerated() {
            let v = marimba(mtof(Double(m)), k == 3 ? 1.4 : 0.5)
            let s = k * seconds(0.11)
            for (i, x) in v.enumerated() where s + i < out.count { out[s + i] += x * 0.45 }
        }
        let chord = pad([mtof(72), mtof(76), mtof(79)], 1.3, cutoff: 2500, attack: 0.05)
        for (i, x) in chord.enumerated() where seconds(0.45) + i < out.count { out[seconds(0.45) + i] += x * 0.5 }
    case "stage_fail":
        // Two soft falling notes — gentle, not scolding.
        out = [Double](repeating: 0, count: seconds(1.0))
        for (k, m) in [67, 62].enumerated() {
            let v = marimba(mtof(Double(m)), 0.6)
            let s = k * seconds(0.22)
            for (i, x) in v.enumerated() where s + i < out.count { out[s + i] += x * 0.5 }
        }
    case "collision":
        // Cartoon "boing": a pitch-bent thump.
        var phase = 0.0
        out = (0..<seconds(0.4)).map { i in
            let t = Double(i) / sr
            phase += twoPi * (90 + 160 * exp(-t * 14) + 25 * sin(twoPi * 18 * t) * exp(-t * 6)) / sr
            return sin(phase) * exp(-t * 7)
        }
    case "timer_tick":
        out = (0..<seconds(0.12)).map { i in
            let t = Double(i) / sr
            return (sin(twoPi * 1600 * t) * 0.6 + sin(twoPi * 2400 * t) * 0.3) * exp(-t * 60)
        }
    case "button_tap":
        out = (0..<seconds(0.08)).map { i in
            let t = Double(i) / sr
            return sin(twoPi * (900 - 2500 * t) * t) * exp(-t * 70)
        }
    default:
        out = []
    }
    let peak = out.map(abs).max() ?? 1
    return out.map { $0 / max(peak, 1e-9) * 0.8 }
}

// MARK: - Main

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/audio-wav"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for song in songs {
    let mix = render(song)
    writeWav("\(outDir)/bgm_\(song.name).wav", left: mix.l, right: mix.r)
    print("bgm_\(song.name)  \(String(format: "%.1f", Double(mix.count) / sr)) s")
}
for name in ["jet_whoosh", "jet_whoosh_soft", "glide_wind", "copter_spin", "balloon_hiss", "balloon_inflate", "cloud_whoosh"] {
    writeWav("\(outDir)/vehicle_\(name).wav", left: vehicleLoop(name), right: nil)
    print("vehicle_\(name)")
}
for name in ["star_collect", "ring_pass", "boost", "stage_clear", "stage_fail", "collision", "timer_tick", "button_tap"] {
    writeWav("\(outDir)/sfx_\(name).wav", left: sfx(name), right: nil)
    print("sfx_\(name)")
}
