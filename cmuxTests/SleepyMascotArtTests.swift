import CmuxSettingsUI
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// The grid mascots share one set of face anchors (`openEyes` / `closedEyes` /
/// `mouthTop` / `mouthOpen`), drawn on top of whatever sprite is selected. A new
/// mascot whose head does not cover those anchors renders eyes and a mouth
/// floating in empty space, which no unit-free visual check would catch.
@Suite("Sleepy Mode mascot art")
struct SleepyMascotArtTests {
    /// Every sprite is 16 rows tall so the mascots share a footprint, and every
    /// row within a sprite is the same width so the grid is not ragged. Width
    /// itself is per-mascot on purpose — see `exaSpriteKeepsTheMarksAspectRatio`.
    @Test("Sprites are 16 rows tall with a consistent width", arguments: SleepyMascot.allCases)
    func spriteGridIsWellFormed(mascot: SleepyMascot) {
        let rows = SleepyArt.mascotRows(mascot)
        // logoFace draws procedurally from the chevron, not from a grid.
        guard mascot != .logoFace else {
            #expect(rows.isEmpty)
            return
        }
        #expect(rows.count == 16, "\(mascot.rawValue) has \(rows.count) rows")
        let widths = Set(rows.map(\.count))
        #expect(widths.count == 1, "\(mascot.rawValue) has ragged rows: \(widths.sorted())")
        // The shared face anchors reach column 11, so anything wearing the face
        // must be the full 16 wide or the eyes hang off the sprite.
        if mascot.wearsSharedFace {
            #expect(rows.first?.count == 16, "\(mascot.rawValue) wears the face but is not 16 wide")
        }
    }

    /// The mark is 328x404. Squeezing it into the square grid the other mascots
    /// use stretches it about 23% horizontally, which is obvious on screen — it
    /// shipped that way once already.
    @Test("The Exa sprite keeps the mark's aspect ratio")
    func exaSpriteKeepsTheMarksAspectRatio() {
        let rows = SleepyArt.mascotRows(.exa)
        let width = rows.first?.count ?? 0
        #expect(width == 13, "Exa sprite is \(width) wide; 13x16 is what matches the 328x404 mark")
        let spriteAspect = Double(width) / Double(rows.count)
        let markAspect = 328.0 / 404.0
        #expect(
            abs(spriteAspect - markAspect) < 0.02,
            "Exa sprite aspect \(spriteAspect) drifted from the mark's \(markAspect)"
        )
    }

    /// Only mascots that wear the shared face need head under the anchors. A
    /// logo mark opts out precisely because it has holes there.
    @Test("Face-wearing mascots have head under every shared anchor", arguments: SleepyMascot.allCases)
    func faceAnchorsLandOnTheHead(mascot: SleepyMascot) {
        let rows = SleepyArt.mascotRows(mascot)
        guard !rows.isEmpty, mascot.wearsSharedFace else { return }
        let anchors = SleepyArt.openEyes + SleepyArt.closedEyes + SleepyArt.mouthTop + SleepyArt.mouthOpen
        for (col, row) in anchors {
            #expect(
                Self.pixel(rows, col: col, row: row) != ".",
                "\(mascot.rawValue) has a hole under the face anchor at (\(col), \(row))"
            )
        }
    }

    /// Painting blinking eyes and a mouth onto line art reads as noise, so the
    /// logo marks must stay opted out. This is the invariant that keeps the
    /// renderer's `wearsSharedFace` branch honest.
    @Test("Logo mascots opt out of the shared face")
    func logoMascotsHaveNoFace() {
        #expect(SleepyMascot.exa.wearsSharedFace == false)
        #expect(SleepyMascot.logoFace.wearsSharedFace == false)
        #expect(SleepyMascot.cmux.wearsSharedFace)
        #expect(SleepyMascot.cat.wearsSharedFace)
        #expect(SleepyMascot.ghost.wearsSharedFace)
    }

    /// Rasterized from the official asset, so the distinguishing features are
    /// the full-height left spine, the full-width top and bottom bars, and the
    /// hourglass pinch where the diagonals meet.
    @Test("The Exa mark keeps its spine, bars and hourglass pinch")
    func exaMarkGeometry() {
        let rows = SleepyArt.mascotRows(.exa)
        let width = rows.first?.count ?? 0
        for row in rows.indices {
            #expect(Self.pixel(rows, col: 0, row: row) == "E", "Exa spine broken at row \(row)")
        }
        for col in 0..<width {
            #expect(Self.pixel(rows, col: col, row: 0) == "E", "Exa top bar broken at column \(col)")
            #expect(Self.pixel(rows, col: col, row: 15) == "E", "Exa bottom bar broken at column \(col)")
        }
        // The waist: the mid bar runs left, and the right half is open there.
        #expect(Self.pixel(rows, col: 7, row: 7) == "E")
        #expect(Self.pixel(rows, col: 10, row: 7) == ".")
        // Counter-space inside the upper triangle stays open.
        #expect(Self.pixel(rows, col: 6, row: 2) == ".")
    }

    /// Every mascot is drawn from the theme palette; a stray character would
    /// silently render as nothing.
    @Test("Sprites only use known palette characters", arguments: SleepyMascot.allCases)
    func spritesUseKnownPaletteCharacters(mascot: SleepyMascot) {
        let known = Set("OoPpWBHCcEY.")
        for (index, row) in SleepyArt.mascotRows(mascot).enumerated() {
            for character in row where !known.contains(character) {
                Issue.record("\(mascot.rawValue) row \(index) uses unknown palette character '\(character)'")
            }
        }
    }

    /// Every character a sprite uses has to exist in every theme's palette, or
    /// those pixels silently render as nothing.
    @Test("Every theme resolves every character the sprites use", arguments: SleepyTheme.allCases)
    func paletteCoversEverySpriteCharacter(theme: SleepyTheme) {
        var config = SleepyModeConfig()
        config.theme = theme
        let palette = SleepyPalette.colors(for: config)
        for mascot in SleepyMascot.allCases {
            for row in SleepyArt.mascotRows(mascot) {
                for character in row where character != "." {
                    #expect(
                        palette[character] != nil,
                        "theme \(theme.rawValue) has no color for '\(character)' used by \(mascot.rawValue)"
                    )
                }
            }
        }
    }

    private static func pixel(_ rows: [String], col: Int, row: Int) -> Character {
        let line = Array(rows[row])
        return line[col]
    }
}
