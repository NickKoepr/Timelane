import Testing
@testable import Timelane

struct PinchZoomStepperTests {
    @Test func smallPositiveDeltasGiveOneStepPerQuarter() {
        var stepper = PinchZoomStepper()
        var steps: [Int] = []
        for _ in 0..<30 { steps.append(stepper.step(forDelta: 0.02)) }
        // 1.02^12 is the first product >= 1.25; the next step needs a further 25% (another 12 events).
        #expect(steps.firstIndex(of: 1) == 11)
        #expect(steps.filter { $0 == 1 }.count == 2)
        #expect(steps.filter { $0 == -1 }.isEmpty)
    }

    @Test func negativeDeltasGiveZoomOutSteps() {
        var stepper = PinchZoomStepper()
        let steps = (0..<30).map { _ in stepper.step(forDelta: -0.02) }
        #expect(steps.filter { $0 == -1 }.count >= 1)
        #expect(steps.filter { $0 == 1 }.isEmpty)
    }

    @Test func oneBigJumpGivesAtMostOneStep() {
        var stepper = PinchZoomStepper()
        #expect(stepper.step(forDelta: 5) == 1)
        #expect(stepper.step(forDelta: 0) == 0)
    }

    @Test func resetStartsFromOneAgain() {
        var stepper = PinchZoomStepper()
        _ = stepper.step(forDelta: 0.2)
        stepper.reset()
        #expect(stepper.step(forDelta: 0.2) == 0)
        #expect(stepper.step(forDelta: 0.2) == 1)
    }

    @Test func deltaAtOrBelowMinusOneDoesNotCrash() {
        var stepper = PinchZoomStepper()
        #expect(stepper.step(forDelta: -1) == 0)
        #expect(stepper.step(forDelta: 0.5) == 0)
        #expect(stepper.step(forDelta: -2) == 0)
    }
}
