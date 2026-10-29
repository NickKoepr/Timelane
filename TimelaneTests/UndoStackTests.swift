import Foundation
import Testing
@testable import Timelane

struct UndoStackTests {
    @Test func undoAndRedoMoveElementsBetweenStacks() {
        var stack = UndoStack<Int>()
        stack.record(1); stack.record(2)
        #expect(stack.nextUndo == 2)
        stack.didUndo()
        #expect(stack.nextRedo == 2 && stack.nextUndo == 1)
        stack.didRedo()
        #expect(stack.nextUndo == 2 && !stack.canRedo)
    }

    @Test func recordClearsRedo() {
        var stack = UndoStack<Int>()
        stack.record(1)
        stack.didUndo()
        #expect(stack.canRedo)
        stack.record(2)
        #expect(!stack.canRedo)
    }

    @Test func capsTheUndoStack() {
        var stack = UndoStack<Int>(limit: 50)
        for index in 0..<60 { stack.record(index) }
        #expect(stack.undoStack.count == 50)
        #expect(stack.undoStack.first == 10)
    }

    @Test func changeInvertedSwapsBeforeAndAfter() {
        let a = TimeEntry(id: 1, projectId: 1, start: .now, end: .now.addingTimeInterval(60))
        let b = TimeEntry(id: 2, projectId: 1, start: .now, end: .now.addingTimeInterval(120))
        let change = TimeEntryChange(before: [a], after: [a, b])
        #expect(change.inverted == TimeEntryChange(before: [a, b], after: [a]))
        #expect(change.inverted.removedIds == [2])
        #expect(change.removedIds.isEmpty)
    }
}
