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
    @Test("Every grid mascot is a 16x16 sprite", arguments: SleepyMascot.allCases)
    func spritesAreSquare(mascot: SleepyMascot) {
        let rows = SleepyArt.mascotRows(mascot)
        // logoFace draws procedurally from the chevron, not from a grid.
        guard mascot != .logoFace else {
            #expect(rows.isEmpty)
            return
        }
        #expect(rows.count == 16, "\(mascot.rawValue) has \(rows.count) rows")
        for (index, row) in rows.enumerated() {
            #expect(row.count == 16, "\(mascot.rawValue) row \(index) is \(row.count) wide")
        }
    }

    @Test("Every grid mascot has face under the shared eye and mouth anchors", arguments: SleepyMascot.allCases)
    func faceAnchorsLandOnTheHead(mascot: SleepyMascot) {
        let rows = SleepyArt.mascotRows(mascot)
        guard !rows.isEmpty else { return }
        let anchors = SleepyArt.openEyes + SleepyArt.closedEyes + SleepyArt.mouthTop + SleepyArt.mouthOpen
        for (col, row) in anchors {
            #expect(
                Self.pixel(rows, col: col, row: row) != ".",
                "\(mascot.rawValue) has a hole under the face anchor at (\(col), \(row))"
            )
        }
    }

    @Test("The bunny carries the shared blush pixels")
    func bunnyHasBlush() {
        let rows = SleepyArt.mascotRows(.bunny)
        for col in [3, 4, 11, 12] {
            #expect(Self.pixel(rows, col: col, row: 8) == "B", "bunny is missing blush at column \(col)")
        }
    }

    /// The ears are the whole point of the sprite: they have to sit above the
    /// face band rather than overlap the eye rows.
    @Test("The bunny's ears rise above the face band")
    func bunnyEarsClearTheFace() {
        let rows = SleepyArt.mascotRows(.bunny)
        // Row 0 is the solid ear tip; the blush lining runs from row 1 down.
        #expect(Self.pixel(rows, col: 5, row: 0) == "O")
        #expect(Self.pixel(rows, col: 10, row: 0) == "O")
        for row in 1...3 {
            #expect(Self.pixel(rows, col: 5, row: row) == "B", "bunny ear lining missing at row \(row)")
            #expect(Self.pixel(rows, col: 10, row: row) == "B", "bunny ear lining missing at row \(row)")
        }
        // The gap between the ears must stay transparent, or they read as one block.
        for row in 0...3 {
            #expect(Self.pixel(rows, col: 7, row: row) == ".", "bunny ears are fused at row \(row)")
        }
    }

    private static func pixel(_ rows: [String], col: Int, row: Int) -> Character {
        let line = Array(rows[row])
        return line[col]
    }
}
