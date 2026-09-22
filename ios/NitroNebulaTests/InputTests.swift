import XCTest
import NitroEngine
@testable import NitroNebula

nonisolated final class InputTests: XCTestCase {

    // MARK: FloatingJoystick

    @MainActor func testDeadZoneReturnsZero() {
        var j = FloatingJoystick(anchor: CGPoint(x: 100, y: 100))
        XCTAssertEqual(j.vector, .zero)
        j.update(touch: CGPoint(x: 105, y: 100))
        XCTAssertEqual(j.vector, .zero)
        j.update(touch: CGPoint(x: 100, y: 108))
        XCTAssertEqual(j.vector, .zero, "exactly the dead zone edge is still zero")
    }

    @MainActor func testHalfDeflectionRamps() {
        var j = FloatingJoystick(anchor: CGPoint(x: 100, y: 100))
        j.update(touch: CGPoint(x: 130, y: 100))
        // (30 - 8) / (60 - 8)
        XCTAssertEqual(j.vector.dx, 22.0 / 52.0, accuracy: 1e-9)
        XCTAssertEqual(j.vector.dy, 0, accuracy: 1e-9)
        j.update(touch: CGPoint(x: 100, y: 100 - 34))
        XCTAssertEqual(j.vector.dy, -(26.0 / 52.0), accuracy: 1e-9)
        XCTAssertEqual(j.vector.dx, 0, accuracy: 1e-9)
    }

    @MainActor func testFullDeflectionIsUnitVector() {
        var j = FloatingJoystick(anchor: CGPoint(x: 100, y: 100))
        j.update(touch: CGPoint(x: 160, y: 100))
        XCTAssertEqual(j.vector.dx, 1, accuracy: 1e-9)
        j.update(touch: CGPoint(x: 100 + 300, y: 100 + 400))
        let v = j.vector
        XCTAssertEqual((v.dx * v.dx + v.dy * v.dy).squareRoot(), 1, accuracy: 1e-9)
        XCTAssertEqual(v.dx, 0.6, accuracy: 1e-9)
        XCTAssertEqual(v.dy, 0.8, accuracy: 1e-9)
    }

    @MainActor func testKnobClampsAtMaxRadius() {
        var j = FloatingJoystick(anchor: CGPoint(x: 50, y: 50))
        j.update(touch: CGPoint(x: 50, y: 500))
        XCTAssertEqual(j.deflection, 60, accuracy: 1e-9)
        XCTAssertEqual(j.knob.x, 50, accuracy: 1e-9)
        XCTAssertEqual(j.knob.y, 110, accuracy: 1e-9)
        j.update(touch: CGPoint(x: 70, y: 50))
        XCTAssertEqual(j.knob, CGPoint(x: 70, y: 50), "inside the ring the knob is the finger")
    }

    @MainActor func testAnchorStable() {
        var j = FloatingJoystick(anchor: CGPoint(x: 10, y: 20))
        for i in 0..<50 {
            j.update(touch: CGPoint(x: 10 + CGFloat(i) * 7, y: 20 - CGFloat(i) * 3))
        }
        XCTAssertEqual(j.anchor, CGPoint(x: 10, y: 20))
    }

    // MARK: TouchController

    @MainActor private func makeController(_ layout: ControlLayout) -> TouchController {
        let c = TouchController(layout: layout)
        c.zoneSize = CGSize(width: 852, height: 393)
        return c
    }

    @MainActor private func id() -> ObjectIdentifier { ObjectIdentifier(NSObject()) }

    @MainActor func testSplitZoneAssignment() {
        let c = makeController(.split)
        let left = NSObject(), right = NSObject()
        c.begin(ObjectIdentifier(left), at: CGPoint(x: 100, y: 200))
        c.begin(ObjectIdentifier(right), at: CGPoint(x: 700, y: 200))
        c.move(ObjectIdentifier(left), to: CGPoint(x: 160, y: 200))
        c.move(ObjectIdentifier(right), to: CGPoint(x: 700, y: 140))
        let s = c.sample()
        XCTAssertEqual(s.pilot1.dx, 1, accuracy: 1e-9)
        XCTAssertEqual(s.pilot1.dy, 0, accuracy: 1e-9)
        XCTAssertEqual(s.pilot2.dx, 0, accuracy: 1e-9)
        XCTAssertEqual(s.pilot2.dy, -1, accuracy: 1e-9)
        XCTAssertEqual(c.overlayState.sticks.count, 2)
        withExtendedLifetime((left, right)) {}
    }

    @MainActor func testSingleLayoutWholeScreenIsPilot1() {
        let c = makeController(.single)
        let t = NSObject()
        c.begin(ObjectIdentifier(t), at: CGPoint(x: 800, y: 300))
        c.move(ObjectIdentifier(t), to: CGPoint(x: 800, y: 360))
        let s = c.sample()
        XCTAssertEqual(s.pilot1.dy, 1, accuracy: 1e-9)
        XCTAssertEqual(s.pilot2, .zero)
        withExtendedLifetime(t) {}
    }

    @MainActor func testSecondTouchInSameZoneIgnored() {
        let c = makeController(.split)
        let first = NSObject(), second = NSObject()
        c.begin(ObjectIdentifier(first), at: CGPoint(x: 100, y: 200))
        c.begin(ObjectIdentifier(second), at: CGPoint(x: 200, y: 200))
        c.move(ObjectIdentifier(second), to: CGPoint(x: 300, y: 200))
        XCTAssertEqual(c.sample().pilot1, .zero, "the ignored touch must not steer")
        XCTAssertEqual(c.stick(for: .player1)?.anchor, CGPoint(x: 100, y: 200))
        c.move(ObjectIdentifier(first), to: CGPoint(x: 100, y: 260))
        XCTAssertEqual(c.sample().pilot1.dy, 1, accuracy: 1e-9)
        c.end(ObjectIdentifier(second))
        XCTAssertTrue(c.stick(for: .player1) != nil, "ending the ignored touch leaves the owner alone")
        withExtendedLifetime((first, second)) {}
    }

    @MainActor func testOwnershipPersistsAcrossMidline() {
        let c = makeController(.split)
        let t = NSObject()
        c.begin(ObjectIdentifier(t), at: CGPoint(x: 400, y: 200))   // left half
        c.move(ObjectIdentifier(t), to: CGPoint(x: 460, y: 200))    // now on the right half
        let s = c.sample()
        XCTAssertEqual(s.pilot1.dx, 1, accuracy: 1e-9)
        XCTAssertEqual(s.pilot2, .zero)
        XCTAssertTrue(c.stick(for: .player1) != nil)
        XCTAssertTrue(c.stick(for: .player2) == nil)
        // A new touch on the right still gets pilot 2.
        let t2 = NSObject()
        c.begin(ObjectIdentifier(t2), at: CGPoint(x: 700, y: 200))
        XCTAssertTrue(c.stick(for: .player2) != nil)
        withExtendedLifetime((t, t2)) {}
    }

    @MainActor func testReleaseZeroesAndFades() {
        let c = makeController(.single)
        let t = NSObject()
        c.begin(ObjectIdentifier(t), at: CGPoint(x: 100, y: 100))
        c.move(ObjectIdentifier(t), to: CGPoint(x: 160, y: 100))
        XCTAssertEqual(c.sample().pilot1.dx, 1, accuracy: 1e-9)
        c.end(ObjectIdentifier(t))
        XCTAssertEqual(c.sample().pilot1, .zero)
        XCTAssertTrue(c.stick(for: .player1) == nil)
        // Fading stick is still drawn, then disappears after ~10 ticks.
        XCTAssertEqual(c.overlayState.sticks.count, 1)
        XCTAssertLessThan(c.overlayState.sticks[0].opacity, 1)
        for _ in 0..<TouchController.fadeTicks { _ = c.sample() }
        XCTAssertTrue(c.overlayState.sticks.isEmpty)
        withExtendedLifetime(t) {}
    }

    @MainActor func testClearAll() {
        let c = makeController(.split)
        let a = NSObject(), b = NSObject()
        c.begin(ObjectIdentifier(a), at: CGPoint(x: 100, y: 200))
        c.begin(ObjectIdentifier(b), at: CGPoint(x: 700, y: 200))
        c.move(ObjectIdentifier(a), to: CGPoint(x: 160, y: 200))
        c.clearAll()
        XCTAssertEqual(c.sample(), InputState())
        XCTAssertTrue(c.overlayState.sticks.isEmpty)
        // Zones are free again.
        c.begin(ObjectIdentifier(b), at: CGPoint(x: 100, y: 200))
        XCTAssertTrue(c.stick(for: .player1) != nil)
        withExtendedLifetime((a, b)) {}
    }

    @MainActor func testLayoutChangeDropsSticks() {
        let c = makeController(.split)
        let a = NSObject()
        c.begin(ObjectIdentifier(a), at: CGPoint(x: 700, y: 200))
        XCTAssertTrue(c.stick(for: .player2) != nil)
        c.layout = .single
        XCTAssertTrue(c.stick(for: .player2) == nil)
        withExtendedLifetime(a) {}
    }
}
