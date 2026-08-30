import CmuxSettingsUI
import Foundation

// MARK: - Pixel art assets

enum SleepyArt {
    /// Shared face anchors for the grid mascots (cmux/cat/ghost).
    static let closedEyes: [(Int, Int)] = [(4, 7), (7, 7), (5, 8), (6, 8), (8, 7), (11, 7), (9, 8), (10, 8)]
    static let openEyes: [(Int, Int)] = [(5, 7), (6, 7), (5, 8), (6, 8), (9, 7), (10, 7), (9, 8), (10, 8)]
    static let mouthTop: [(Int, Int)] = [(7, 10), (8, 10)]
    static let mouthOpen: [(Int, Int)] = [(7, 11), (8, 11)]

    static func mascotRows(_ mascot: SleepyMascot) -> [String] {
        switch mascot {
        case .cmux: return cmuxMascot
        case .cat: return catMascot
        case .ghost: return ghostMascot
        case .exa: return exaMascot
        case .logoFace: return []
        }
    }

    /// Head + droopy nightcap (16x16).
    static let cmuxMascot: [String] = [
        "............WW..",
        "..........PPWW..",
        "........PPPPP...",
        "......PPPPPPP...",
        "....PPPPPPPPP...",
        "...PPPPPPPPPP...",
        "...pOOOOOOOOp...",
        "..OOOOOOOOOOOO..",
        "..OBBOOOOOOBBO..",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "...OOOOOOOOOo...",
        "...OOOOOOOOoo...",
        "....OOOOOOoo....",
        ".....OOOOoo.....",
        "................",
    ]

    /// Cat: round head with pointy ears and whiskers (16x16).
    static let catMascot: [String] = [
        "................",
        "....O......O....",
        "...OBO....OBO...",
        "..OOOO....OOOO..",
        "..OOOOO..OOOOO..",
        "...OOOOOOOOOO...",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OBBOOOOOOBBO..",
        "o.OOOOOOOOOOOO.o",
        "o.OOOOOOOOOOOO.o",
        "...OOOOOOOOOO...",
        "...OOOOOOOOOO...",
        "....OOOOOOOO....",
        ".....OOOOOO.....",
        "................",
    ]

    /// The Exa "E/X" monogram (13x16), rasterized from the official asset
    /// rather than eyeballed. Flat `E` strokes: the mark has no bevel, and `E`
    /// is Exa brand blue, which every theme leaves alone.
    ///
    /// 13 wide, not 16: the real mark is 328x404, and forcing a non-square mark
    /// into the square grid the other mascots use stretches it ~23% horizontally.
    /// `drawSprite` uses square pixels and centers on `rows`/`cols`, so an
    /// off-square sprite renders at the correct proportions on its own.
    ///
    /// Line art, not a head. It opts out of the shared face anchors via
    /// `SleepyMascot.wearsSharedFace`, because eyes and a mouth land on the
    /// strokes and read as noise.
    static let exaMascot: [String] = [
        "EEEEEEEEEEEEE",
        "EEEEEEEEEEEEE",
        "EEE.......EE.",
        "EEEE.....EE..",
        "EE.EE...EE...",
        "EE..EE..EE...",
        "EE...EEEE....",
        "EEEEEEEE.....",
        "EEEEEEEE.....",
        "EE...EEEE....",
        "EE..EE..EE...",
        "EE.EE...EE...",
        "EEEE.....EE..",
        "EEE.......EE.",
        "EEEEEEEEEEEEE",
        "EEEEEEEEEEEEE",
    ]

    /// Ghost: domed top, wavy feet (16x16).
    static let ghostMascot: [String] = [
        "................",
        "................",
        "................",
        "....OOOOOOOO....",
        "...OOOOOOOOOO...",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OBBOOOOOOBBO..",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OOOOOOOOOOOO..",
        "..OOO.OOO.OOO...",
    ]

    /// Detailed beveled right-pointing cmux chevron (11x15): highlight (H) on the
    /// leading edge, main (C) body, shadow (c) trailing edge. Doubles as the left
    /// eye of the logoFace mascot.
    static let cmuxLogo: [String] = [
        "HCCc.......",
        ".HCCc......",
        "..HCCc.....",
        "...HCCc....",
        "....HCCc...",
        ".....HCCc..",
        "......HCCc.",
        ".......HCCc",
        "......HCCc.",
        ".....HCCc..",
        "....HCCc...",
        "...HCCc....",
        "..HCCc.....",
        ".HCCc......",
        "HCCc.......",
    ]

    static let moon: [String] = [
        ".YY..",
        "YYY..",
        "YY...",
        "YYY..",
        ".YY..",
    ]

    static let zGlyph: [String] = [
        "ZZZZZ",
        "...Z.",
        "..Z..",
        ".Z...",
        "ZZZZZ",
    ]

    // 3x5 pixel font (digits, colon, slash).
    static let font: [Character: [String]] = [
        "0": ["###", "#.#", "#.#", "#.#", "###"],
        "1": [".#.", "##.", ".#.", ".#.", "###"],
        "2": ["###", "..#", "###", "#..", "###"],
        "3": ["###", "..#", "###", "..#", "###"],
        "4": ["#.#", "#.#", "###", "..#", "..#"],
        "5": ["###", "#..", "###", "..#", "###"],
        "6": ["###", "#..", "###", "#.#", "###"],
        "7": ["###", "..#", "..#", "..#", "..#"],
        "8": ["###", "#.#", "###", "#.#", "###"],
        "9": ["###", "#.#", "###", "..#", "###"],
        ":": [".", "#", ".", "#", "."],
        "/": ["..#", "..#", ".#.", "#..", "#.."],
    ]

    /// Precomputed glyph rows for the clock, so the 30fps render path never
    /// allocates strings (no per-frame `String(format:)`).
    static let digitGlyphs: [[String]] = (0...9).map { font[Character(String($0))] ?? [] }
    static let colonGlyph: [String] = font[":"] ?? []
    static let slashGlyph: [String] = font["/"] ?? []


    static let stars: [SleepyStar] = [
        SleepyStar(x: 0.22, y: 0.34, big: true, speed: 1.7, phase: 0.0),
        SleepyStar(x: 0.80, y: 0.24, big: false, speed: 2.1, phase: 1.2),
        SleepyStar(x: 0.66, y: 0.40, big: false, speed: 2.6, phase: 0.5),
        SleepyStar(x: 0.88, y: 0.52, big: false, speed: 1.9, phase: 2.0),
        SleepyStar(x: 0.12, y: 0.56, big: false, speed: 2.3, phase: 3.1),
        SleepyStar(x: 0.30, y: 0.70, big: true, speed: 1.5, phase: 0.8),
        SleepyStar(x: 0.82, y: 0.72, big: false, speed: 2.8, phase: 1.7),
        SleepyStar(x: 0.52, y: 0.62, big: false, speed: 2.2, phase: 2.6),
    ]
}
