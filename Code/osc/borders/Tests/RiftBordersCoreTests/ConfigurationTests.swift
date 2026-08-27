import XCTest
import CoreGraphics
@testable import RiftBordersCore

final class ConfigurationTests: XCTestCase {
    func testParsesActiveAndInactiveAppearance() throws {
        let config = try ConfigurationLoader.parse("""
        width = 4
        gap = -1
        shape = "round"
        [active]
        paint = "glow"
        color = "#ff112233"
        [inactive]
        opacity = 0.25
        """)
        XCTAssertEqual(config.width, 4)
        XCTAssertEqual(config.gap, -1)
        XCTAssertEqual(config.active.paint, .glow)
        XCTAssertEqual(config.active.color.alpha, 255)
        XCTAssertEqual(config.active.color.red, 17)
        XCTAssertEqual(config.inactive.opacity, 0.25)
    }

    func testParsesQuotedAppSectionAndExclusions() throws {
        let config = try ConfigurationLoader.parse("""
        excluded_bundle_identifiers = ["com.apple.Spotlight"]
        [apps."WhatsApp"]
        radius = 13.5
        inactive_opacity = 0.2
        """)
        XCTAssertTrue(config.excludedBundleIdentifiers.contains("com.apple.Spotlight"))
        XCTAssertEqual(config.apps["WhatsApp"]?.radius, 13.5)
        XCTAssertEqual(config.apps["WhatsApp"]?.inactive?.opacity, 0.2)
    }
}

final class GeometryTests: XCTestCase {
    func testConvertsDisplayAbovePrimaryWithoutPrimaryHeightAssumption() {
        let display = DisplayGeometry(
            cocoaFrame: CGRect(x: 0, y: 900, width: 1920, height: 1080),
            cgFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        )
        XCTAssertEqual(display.cocoaRect(for: CGRect(x: 100, y: -980, width: 400, height: 300)), CGRect(x: 100, y: 1580, width: 400, height: 300))
    }

    func testOverlayFrameHonorsWidthAndGap() {
        XCTAssertEqual(
            BorderGeometry.overlayFrame(windowFrame: CGRect(x: 10, y: 10, width: 100, height: 80), width: 3, gap: -1),
            CGRect(x: 9.5, y: 9.5, width: 101, height: 81)
        )
    }

    func testTopLevelSelectionRejectsContainedSameOwnerWindow() {
        let browser = WindowFrameCandidate(id: 1, ownerName: "Helium",
                                           frame: CGRect(x: 0, y: 0, width: 1200, height: 800))
        let suggestions = WindowFrameCandidate(id: 2, ownerName: "Helium",
                                               frame: CGRect(x: 300, y: -12, width: 500, height: 312))
        let otherWindow = WindowFrameCandidate(id: 3, ownerName: "Helium",
                                               frame: CGRect(x: 1300, y: 0, width: 900, height: 700))

        XCTAssertEqual(WindowSelection.topLevel([browser, suggestions, otherWindow]),
                       [browser, otherWindow])
    }
}
