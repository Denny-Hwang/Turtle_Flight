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
//
// 2026-11-26 rewrite (docs/FLIGHT_FUN_PLAN.md §5, M1–M3). The first
// version looped one 8-chord progression for ~40 s with a melody that
// copied a two-bar motif, flat drums and flat levels — "monotonous"
// (owner). Now each world's tune has a form:
//
//   A → A′ → B → breakdown → A″ → B′ → A‴   (≈2 min, loops back to A)
//
// - B has its own progression and swaps the lead and counter voices.
// - One motif per song is developed rather than copied: stated,
//   sequenced up/down the scale, inverted for B, ornamented later.
//   Phrases end on a half cadence (5th) the first time, the tonic after.
// - Texture and dynamics follow the form: lighter drums in A, half-time
//   in B, a crescendo into the breakdown, drums and bass out in the
//   breakdown, full band plus fills every 4 bars in A″/A‴. Notes get
//   accents on strong beats and a few milliseconds of human timing.

/// One world's tune: two progressions, a scale, a groove and a band.
struct Song {
    enum Lead { case marimba, pluck, reed, gayageum, flute, bell }
    enum Groove { case pop, darbuka, waltz, janggu, tribal, none, tide }

    let name: String
    let bpm: Double
    let beatsPerBar: Int
    /// Scale as semitones above `root`.
    let scale: [Int]
    let root: Int
    /// A-section progression, one chord per bar (MIDI notes), 8 bars.
    let chords: [[Int]]
    /// B-section progression, 8 bars; ends on a chord that leads home.
    let bChords: [[Int]]
    /// Each section's 8 (or 4) bars are played this many times — the
    /// quick 3/4 waltz needs 2 to reach the same length.
    let sectionReps: Int
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

/// A part of the form and how it is played.
struct Section {
    enum Kind { case a, b, breakdown }
    let kind: Kind
    /// Which variation (0 = first statement).
    let variant: Int

    var bars: Int { kind == .breakdown ? 4 : 8 }
    /// 0 = no drums, 1 = light, 2 = half-time, 3 = full, 4 = driving.
    var drums: Int {
        switch (kind, variant) {
        case (.a, 0): return 1
        case (.a, 1): return 3
        case (.a, _): return 4
        case (.b, _): return 2
        case (.breakdown, _): return 0
        }
    }
    var gain: Double {
        switch kind {
        case .a: return variant == 0 ? 0.88 : 1.0
        case .b: return 0.92
        case .breakdown: return 0.72
        }
    }
    var counterOn: Bool { kind == .a ? variant > 0 : (kind == .b && variant > 0) }
}

let form: [Section] = [
    Section(kind: .a, variant: 0), Section(kind: .a, variant: 1), Section(kind: .b, variant: 0),
    Section(kind: .breakdown, variant: 0), Section(kind: .a, variant: 2), Section(kind: .b, variant: 1),
    Section(kind: .a, variant: 3),
]

typealias Note = (beat: Double, len: Double, midi: Int)

/// Scale notes the melody may use, low to high.
func usableNotes(_ song: Song) -> [Int] {
    var notes: [Int] = []
    for octave in -1...2 { for s in song.scale { notes.append(song.root + octave * 12 + s) } }
    let low = song.root - 3, high = song.root + 16
    return notes.sorted().filter { $0 >= low && $0 <= high }
}

func nearest(_ target: Int, in set: [Int]) -> Int {
    set.min { abs($0 - target) < abs($1 - target) } ?? target
}

func chordTones(_ chord: [Int], _ usable: [Int]) -> [Int] {
    let tones = usable.filter { n in chord.contains { (($0 - n) % 12 + 12) % 12 == 0 } }
    return tones.isEmpty ? usable : tones
}

func isStrong(_ beatInBar: Double, _ song: Song) -> Bool {
    guard beatInBar.truncatingRemainder(dividingBy: 1) == 0 else { return false }
    return song.beatsPerBar == 3 ? beatInBar == 0 : Int(beatInBar) % 2 == 0
}

/// Free melodic line over `chords` (one bar each): chord tones on strong
/// beats, steps between, the odd rest.
func freeLine(_ song: Song, chords: [[Int]], from prevNote: Int, seed: UInt64) -> [Note] {
    var rng = Rng(seed)
    let usable = usableNotes(song)
    let bpb = Double(song.beatsPerBar)
    let cells: [[Double]] = song.beatsPerBar == 3
        ? [[1, 1, 1], [2, 1], [1.5, 0.5, 1], [1, 2]]
        : (song.density >= 2
            ? [[1, 0.5, 0.5, 1, 1], [0.5, 0.5, 1, 0.5, 0.5, 1], [1.5, 0.5, 2], [1, 1, 0.5, 0.5, 1], [2, 1, 1]]
            : [[2, 2], [1, 1, 2], [3, 1], [1.5, 0.5, 2], [2, 1, 1]])
    var out: [Note] = []
    var prev = prevNote
    for (bar, chord) in chords.enumerated() {
        let tones = chordTones(chord, usable)
        var b = 0.0
        for len in cells[rng.int(cells.count)] {
            if b > 0 && rng.chance(0.12) { b += len; continue }
            var next: Int
            if isStrong(b, song) || rng.chance(0.3) {
                let options = tones.filter { abs($0 - prev) <= 7 }
                next = options.isEmpty ? nearest(prev, in: tones) : options[rng.int(options.count)]
            } else {
                let i = usable.firstIndex(of: nearest(prev, in: usable)) ?? 0
                let step = rng.chance(0.5) ? 1 : -1
                let leap = rng.chance(0.15) ? 2 : 1
                next = usable[max(0, min(usable.count - 1, i + step * leap))]
            }
            out.append((Double(bar) * bpb + b, len, next))
            prev = next
            b += len
        }
    }
    return out
}

/// Move a phrase by `steps` scale degrees (a sequence), or mirror it
/// around its first note (inversion); then pull strong-beat notes onto
/// the chords they now sit over.
func develop(_ phrase: [Note], song: Song, chords: [[Int]], steps: Int = 0, invert: Bool = false) -> [Note] {
    let usable = usableNotes(song)
    let bpb = Double(song.beatsPerBar)
    guard let first = phrase.first else { return [] }
    let pivot = usable.firstIndex(of: nearest(first.midi, in: usable)) ?? 0
    return phrase.map { n in
        var i = usable.firstIndex(of: nearest(n.midi, in: usable)) ?? 0
        if invert { i = pivot - (i - pivot) }
        i = max(0, min(usable.count - 1, i + steps))
        var midi = usable[i]
        let bar = min(chords.count - 1, Int(n.beat / bpb))
        if isStrong(n.beat.truncatingRemainder(dividingBy: bpb), song) {
            midi = nearest(midi, in: chordTones(chords[bar], usable))
        }
        return (n.beat, n.len, midi)
    }
}

/// Split each note of a beat or more into two (passing-note ornament).
func ornament(_ phrase: [Note], song: Song) -> [Note] {
    let usable = usableNotes(song)
    var out: [Note] = []
    for (k, n) in phrase.enumerated() {
        if n.len >= 1, k + 1 < phrase.count {
            let target = phrase[k + 1].midi
            let i = usable.firstIndex(of: nearest(n.midi, in: usable)) ?? 0
            let step = target > n.midi ? 1 : -1
            let passing = usable[max(0, min(usable.count - 1, i + step))]
            out.append((n.beat, n.len / 2, n.midi))
            out.append((n.beat + n.len / 2, n.len / 2, passing))
        } else {
            out.append(n)
        }
    }
    return out
}

/// The song's motif: two bars over the first two A chords.
func motif(_ song: Song) -> [Note] {
    freeLine(song, chords: Array(song.chords.prefix(2)), from: song.root + 4, seed: song.seed)
}

/// Melody for one 8-bar section (beats relative to the section start).
func sectionMelody(_ song: Song, _ section: Section) -> [Note] {
    let bpb = Double(song.beatsPerBar)
    let usable = usableNotes(song)
    let m = motif(song)
    let chords = section.kind == .b ? song.bChords : song.chords
    func shifted(_ notes: [Note], bars: Int) -> [Note] { notes.map { ($0.beat + Double(bars) * bpb, $0.len, $0.midi) } }
    func slice(_ from: Int, _ count: Int) -> [[Int]] { Array(chords[from..<(from + count)]) }

    switch section.kind {
    case .breakdown:
        // Sparse: the motif's first note of each beat, an octave up, then
        // one long held note.
        var out: [Note] = []
        for n in m where n.beat.truncatingRemainder(dividingBy: 1) == 0 && n.beat < bpb * 2 {
            out.append((n.beat, 1.5, n.midi + 12))
        }
        let hold = nearest(song.root + 7 + 12, in: chordTones(chords[2], usable.map { $0 + 12 }))
        out.append((bpb * 2.5, bpb * 1.4, hold))
        return out
    case .a, .b:
        let invert = section.kind == .b
        let steps = [0, 2, -1, 3][section.variant % 4] + (invert ? 2 : 0)
        var head = develop(m, song: song, chords: slice(0, 2), steps: invert ? steps : 0, invert: invert)
        if section.variant == 3 { head = ornament(head, song: song) }
        let seq = develop(m, song: song, chords: slice(2, 2), steps: steps == 0 ? 2 : steps, invert: invert)
        let last = seq.last?.midi ?? song.root
        let free = freeLine(song, chords: slice(4, 2), from: last,
                            seed: song.seed &+ UInt64(section.variant * 131 + (invert ? 977 : 0)))
        // Bar 6: the motif's first bar again, mirrored, as the phrase turns.
        let turn = develop(m.filter { $0.beat < bpb }, song: song, chords: slice(6, 1), steps: 1, invert: !invert)
        // Bar 7: cadence — the 5th the first time through and in B (it
        // leads on), the tonic otherwise.
        let toTonic = section.kind == .a && section.variant > 0
        let target = nearest(song.root + (toTonic ? 0 : 7) + (section.variant % 2 == 0 ? 0 : 12),
                             in: chordTones(chords[7], usable))
        return head + shifted(seq, bars: 2) + shifted(free, bars: 4) + shifted(turn, bars: 6)
            + [(bpb * 7, bpb * 0.85, target)]
    }
}

func render(_ song: Song) -> Mix {
    let beat = 60 / song.bpm
    let bpb = Double(song.beatsPerBar)
    let totalBars = form.reduce(0) { $0 + $1.bars * song.sectionReps }
    let loopLen = Int(Double(totalBars) * bpb * beat * sr)
    let mix = Mix(samples: loopLen + Int(5 * sr))
    var rng = Rng(song.seed &* 31)
    var feel = Rng(song.seed &* 977)
    func at(_ b: Double, humanize: Bool = false) -> Int {
        // Never before the loop start: a note nudged below 0 would lose
        // its attack (`Mix.add` drops negative samples).
        max(0, Int(b * beat * sr) + (humanize ? Int(feel.signed() * 0.008 * sr) : 0))
    }

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
        mix.add(v, at: at(b, humanize: true), gain: gain, pan: pan)
    }

    /// One bar of groove at `intensity` (see `Section.drums`), with a fill
    /// in the second half when `fill`.
    func groove(bar b0: Double, intensity: Int, fill: Bool, seedBase: UInt64, level: Double) {
        guard intensity > 0 else { return }
        let steps = Int(bpb * 2)
        for s in 0..<steps {
            let b = b0 + Double(s) * 0.5
            let seed = seedBase &+ UInt64(s)
            let inFill = fill && s >= steps / 2 && intensity >= 3
            if inFill {
                // Two sixteenths per eighth, rising.
                for k in 0..<2 {
                    let bb = b + Double(k) * 0.25
                    let up = Double(s - steps / 2) / Double(steps / 2)
                    switch song.groove {
                    case .pop, .tribal: mix.add(tom(110 + 60 * up), at: at(bb, humanize: true), gain: 0.18 * level, pan: -0.3 + up * 0.6)
                    case .darbuka, .janggu: mix.add(handDrum(low: k == 0 && s == steps / 2, seed: seed &+ UInt64(k)), at: at(bb, humanize: true), gain: 0.2 * level, pan: 0.2)
                    case .waltz: mix.add(shaker(seed &+ UInt64(k)), at: at(bb), gain: 0.1 * level, pan: 0.3)
                    case .tide, .none: break
                    }
                }
                continue
            }
            switch song.groove {
            case .pop:
                let kickSteps: Set<Int> = intensity == 2 ? [0] : (intensity >= 4 ? [0, 3, 4] : [0, 4])
                if kickSteps.contains(s) { mix.add(kick(), at: at(b), gain: 0.32 * level) }
                if intensity >= 3 || s % 2 == 1 {
                    mix.add(shaker(seed), at: at(b, humanize: true), gain: (s % 2 == 1 ? 0.12 : 0.06) * level, pan: 0.3)
                }
                if intensity >= 3 && (s == 2 || s == 6) { mix.add(handDrum(low: false, seed: seed), at: at(b), gain: 0.12 * level, pan: -0.25) }
            case .darbuka:
                let pattern: [Int: Bool] = intensity == 2 ? [0: true, 4: false] : [0: true, 2: false, 4: true, 5: true, 6: false]
                if let low = pattern[s] { mix.add(handDrum(low: low, seed: seed), at: at(b, humanize: true), gain: 0.30 * level, pan: low ? -0.1 : 0.2) }
                if intensity >= 3 && s % 2 == 1 && s != 5 { mix.add(shaker(seed), at: at(b), gain: 0.06 * level, pan: 0.4) }
            case .waltz:
                if s == 2 || s == 4 { mix.add(shaker(seed), at: at(b), gain: 0.07 * level, pan: 0.3) }
                if intensity >= 4 && s == 0 { mix.add(handDrum(low: true, seed: seed), at: at(b), gain: 0.12 * level, pan: -0.2) }
            case .janggu:
                if s == 0 { mix.add(handDrum(low: true, seed: seed), at: at(b), gain: 0.26 * level, pan: -0.2) }
                let taps: Set<Int> = intensity == 2 ? [5] : (intensity >= 4 ? [2, 3, 5, 6] : [3, 5, 6])
                if taps.contains(s) { mix.add(handDrum(low: false, seed: seed), at: at(b, humanize: true), gain: 0.14 * level, pan: 0.25) }
            case .tribal:
                let hits: Set<Int> = intensity == 2 ? [0, 4] : (intensity >= 4 ? [0, 2, 3, 4, 7] : [0, 3, 4])
                if hits.contains(s) { mix.add(tom(s == 3 || s == 7 ? 130 : 95), at: at(b, humanize: true), gain: 0.30 * level, pan: s == 3 ? 0.3 : -0.2) }
                if intensity >= 3 { mix.add(shaker(seed), at: at(b), gain: 0.08 * level, pan: 0.35) }
            case .tide, .none:
                // Ambient worlds: a soft bell tick marks the bar when the
                // band is "full".
                if intensity >= 3 && s == 0 { mix.add(bell(mtof(Double(song.root + 24)), 1.2), at: at(b), gain: 0.03 * level, pan: 0.5) }
            }
        }
    }

    var cursor = 0.0   // beats from loop start
    for (si, section) in form.enumerated() {
        let chords = section.kind == .b ? song.bChords : song.chords
        let lead = section.kind == .b ? (song.counter ?? song.lead) : song.lead
        let counter = section.kind == .b ? song.lead : song.counter
        let melodyNotes = sectionMelody(song, section)
        for rep in 0..<song.sectionReps {
            let sectionStart = cursor
            for bar in 0..<section.bars {
                let chord = chords[bar % chords.count]
                let b0 = sectionStart + Double(bar) * bpb
                // Crescendo through the last two bars of B into the breakdown.
                let swell = section.kind == .b && bar >= section.bars - 2 ? 1.0 + 0.12 * Double(bar - section.bars + 3) : 1.0
                let level = section.gain * swell
                let cutoff = song.padCutoff * (section.kind == .breakdown ? 0.6 : (section.kind == .b ? 0.85 : 1.0))
                mix.add(pad(chord.map { mtof(Double($0)) }, bpb * beat + 0.6, cutoff: cutoff),
                        at: at(b0), gain: 0.22 * (section.kind == .breakdown ? 1.15 : 1.0) * swell, pan: 0)
                let rootNote = chord[0] - 24
                if section.kind == .breakdown {
                    if bar % 2 == 0 { mix.add(bass(mtof(Double(rootNote)), bpb * 2 * beat * 0.9), at: at(b0), gain: 0.12) }
                } else {
                    switch song.groove {
                    case .waltz:
                        mix.add(bass(mtof(Double(rootNote)), beat * 0.9), at: at(b0), gain: 0.30 * level)
                        for k in 1...2 {
                            for (j, n) in chord.enumerated() {
                                mix.add(pluck(mtof(Double(n)), beat * 0.6, bright: 0.4, sustain: 0.99, seed: UInt64(n + k)),
                                        at: at(b0 + Double(k), humanize: true), gain: 0.07 * level, pan: Double(j - 1) * 0.3)
                            }
                        }
                    case .none, .tide:
                        mix.add(bass(mtof(Double(rootNote)), bpb * beat * 0.95), at: at(b0), gain: 0.18 * level)
                    default:
                        mix.add(bass(mtof(Double(rootNote)), beat * 1.8), at: at(b0), gain: 0.26 * level)
                        if section.drums != 2 {
                            mix.add(bass(mtof(Double(rootNote + (rng.chance(0.5) ? 7 : 12))), beat * 1.6),
                                    at: at(b0 + 2), gain: 0.2 * level)
                        }
                    }
                }
                // Arpeggio: on where the song has one, and flipped in B for
                // a change of texture; soft and slow in the breakdown.
                let arpOn = section.kind == .breakdown || (section.kind == .b ? !song.arp : song.arp && section.variant != 0)
                    || (section.kind == .a && section.variant >= 2)
                if arpOn {
                    let tones = chord + chord.map { $0 + 12 }
                    let rate = section.kind == .breakdown ? 1.0 : 0.5
                    let steps = Int(bpb / rate)
                    let arpVoice: Song.Lead = section.kind == .breakdown ? .bell : (song.lead == .gayageum ? .gayageum : .pluck)
                    for s in 0..<steps {
                        let idx = section.kind == .b ? (tones.count - 1 - (s + bar) % tones.count) : (s + bar) % tones.count
                        play(arpVoice, midi: tones[idx], beat: b0 + Double(s) * rate, len: rate,
                             gain: (section.kind == .breakdown ? 0.045 : 0.06 + (s % 2 == 0 ? 0.015 : 0)) * level,
                             pan: s % 2 == 0 ? -0.45 : 0.45)
                    }
                }
                let phraseEnd = bar % 4 == 3
                groove(bar: b0, intensity: section.drums, fill: phraseEnd && section.kind == .a,
                       seedBase: UInt64(si * 10_000 + rep * 1000 + bar * 10), level: level)
            }
            // Melody (and counter line when the section calls for it).
            for (b, len, m) in melodyNotes {
                let inBar = b.truncatingRemainder(dividingBy: bpb)
                let accent = isStrong(inBar, song) ? 1.0 : 0.82
                let bar = Int(b / bpb)
                let swell = section.kind == .b && bar >= section.bars - 2 ? 1.12 : 1.0
                let voice: Song.Lead = section.kind == .breakdown ? .bell : lead
                play(voice, midi: m, beat: sectionStart + b, len: len,
                     gain: 0.26 * accent * section.gain * swell * (1 + feel.signed() * 0.06), pan: -0.1)
                if section.counterOn, let counter {
                    play(counter, midi: m + (counter == .bell ? 12 : 0),
                         beat: sectionStart + b + (counter == .bell ? 0.5 : 0),
                         len: len, gain: 0.11 * accent * section.gain, pan: 0.35)
                }
            }
            cursor += Double(section.bars) * bpb
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
         bChords: [[A - 12, C, E], [F - 12, A - 12, C], [C, E, G], [G - 12, B - 12, D],
                   [D, F, A], [G - 12, B - 12, D], [E - 12, G - 12, B - 12], [G - 12, B - 12, D, F]],
         sectionReps: 1, lead: .marimba, counter: .bell, groove: .pop, arp: true,
         padCutoff: 1500, reverbWet: 0.9, echoWet: 0, density: 2, seed: 11),
    Song(name: "desert", bpm: 92, beatsPerBar: 4, scale: [0, 1, 4, 5, 7, 8, 10], root: D,
         chords: [[D, F + 1, A], [D + 1, G, A + 1], [D, F + 1, A], [C, D + 1, G],
                  [D, F + 1, A], [D + 1, G, A + 1], [G - 12, A + 1 - 12, D], [D, F + 1, A]],
         bChords: [[G - 12, A + 1 - 12, D], [C, D + 1, G], [D + 1, G, A + 1], [D, F + 1, A],
                   [G - 12, A + 1 - 12, D], [D + 1, G, A + 1], [C, D + 1, G], [D, F + 1, A]],
         sectionReps: 1, lead: .pluck, counter: .flute, groove: .darbuka, arp: false,
         padCutoff: 900, reverbWet: 1.0, echoWet: 0.18, density: 2, seed: 23),
    Song(name: "city", bpm: 138, beatsPerBar: 3, scale: [0, 2, 4, 5, 7, 9, 10, 11], root: F,
         chords: [[F, A, C + 12, E + 12], [D, F, A, C + 12], [G - 12, A + 1 - 12, D, F], [C, E, G, A + 1],
                  [F, A, C + 12, E + 12], [A - 12, C, E, G], [A + 1 - 12, D, F, A], [C, E, G, A + 1]],
         bChords: [[A + 1 - 12, D, F], [G - 12, A + 1 - 12, D], [C, E, G, A + 1], [F, A, C + 12],
                   [D, F, A], [A + 1 - 12, D, F], [G - 12, B - 12, D, F], [C, E, G, A + 1]],
         sectionReps: 2, lead: .reed, counter: .marimba, groove: .waltz, arp: false,
         padCutoff: 1100, reverbWet: 0.8, echoWet: 0, density: 1, seed: 37),
    Song(name: "seoul", bpm: 84, beatsPerBar: 4, scale: [0, 2, 4, 7, 9], root: G - 12,
         chords: [[G - 12, B - 12, D], [E - 12, G - 12, B - 12], [C, E, G], [D, A, D + 12],
                  [G - 12, B - 12, D], [E - 12, G - 12, B - 12], [A - 12, C, E], [D, G, A]],
         bChords: [[C, E, G], [A - 12, C, E], [E - 12, G - 12, B - 12], [G - 12, B - 12, D],
                   [C, E, G], [D, A, D + 12], [E - 12, G - 12, B - 12], [D, G, A]],
         sectionReps: 1, lead: .gayageum, counter: .flute, groove: .janggu, arp: false,
         padCutoff: 1000, reverbWet: 1.1, echoWet: 0.15, density: 2, seed: 41),
    Song(name: "wild", bpm: 104, beatsPerBar: 4, scale: [0, 2, 3, 5, 7, 9, 10], root: A - 12,
         chords: [[A - 12, E, A], [G - 12, D, G], [A - 12, E, A], [D, A, D + 12],
                  [A - 12, E, A], [C, G, C + 12], [G - 12, D, G], [E - 12, B - 12, E]],
         bChords: [[D, F + 1, A], [G - 12, B - 12, D], [C, E, G], [A - 12, C, E],
                   [D, F + 1, A], [E - 12, G - 12, B - 12], [G - 12, B - 12, D], [E - 12, G - 12, B - 12]],
         sectionReps: 1, lead: .flute, counter: .pluck, groove: .tribal, arp: true,
         padCutoff: 1200, reverbWet: 1.1, echoWet: 0.1, density: 2, seed: 53),
    Song(name: "space", bpm: 72, beatsPerBar: 4, scale: [0, 2, 4, 6, 7, 9, 11], root: E,
         chords: [[E - 12, G + 1 - 12, B - 12, D + 1], [F + 1 - 12, A + 1 - 12, C + 1], [C + 1 - 12, E - 12, G + 1 - 12, B - 12], [B - 24, D + 1 - 12, F + 1 - 12, A - 12 + 2],
                  [E - 12, G + 1 - 12, B - 12, D + 1], [F + 1 - 12, A + 1 - 12, C + 1], [A - 12, C + 1, E], [B - 24, D + 1 - 12, F + 1 - 12]],
         bChords: [[F + 1 - 12, A + 1 - 12, C + 1], [G + 1 - 12, B - 12, D + 1], [C + 1 - 12, E - 12, G + 1 - 12], [E - 12, G + 1 - 12, B - 12, D + 1],
                   [D + 1 - 12, F + 1 - 12, A + 1 - 12], [F + 1 - 12, A + 1 - 12, C + 1, E], [C + 1 - 12, E - 12, G + 1 - 12, B - 12], [B - 24, D + 1 - 12, F + 1 - 12]],
         sectionReps: 1, lead: .bell, counter: .flute, groove: .none, arp: true,
         padCutoff: 900, reverbWet: 1.6, echoWet: 0.35, density: 1, seed: 67),
    Song(name: "ocean", bpm: 80, beatsPerBar: 4, scale: [0, 2, 4, 5, 7, 9, 11], root: D,
         chords: [[D, F + 1, A, C + 1 + 12], [B - 12, D, F + 1, A], [G - 12, B - 12, D, F + 1], [A - 12, C + 1, E],
                  [D, F + 1, A, C + 1 + 12], [F + 1 - 12, A - 12, C + 1, E], [G - 12, B - 12, D, F + 1], [A - 12, C + 1, E, G]],
         bChords: [[G - 12, B - 12, D], [A - 12, C + 1, E], [F + 1 - 12, A - 12, C + 1], [B - 12, D, F + 1],
                   [G - 12, B - 12, D, F + 1], [E - 12, G - 12, B - 12], [A - 12, C + 1, E, G], [A - 12, C + 1, E]],
         sectionReps: 1, lead: .bell, counter: .flute, groove: .tide, arp: true,
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
