import SwiftUI

extension View {
    /// Shows an alert whenever `message` is non-nil and clears it on dismiss.
    func errorAlert(_ message: Binding<String?>) -> some View {
        messageAlert("Something went wrong", message)
    }

    /// Shows an alert with `title` whenever `message` is non-nil and clears it on dismiss.
    func messageAlert(_ title: String, _ message: Binding<String?>) -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
