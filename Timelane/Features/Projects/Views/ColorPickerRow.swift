import SwiftUI

struct ColorPickerRow: View {
    @Binding var selectedHex: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ProjectColor.palette, id: \.self) { hex in
                Button { selectedHex = hex } label: {
                    Circle()
                        .fill(ProjectColor.color(hex: hex))
                        .frame(width: 22, height: 22)
                        .overlay {
                            if hex == selectedHex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Color \(hex)")
                .accessibilityAddTraits(hex == selectedHex ? .isSelected : [])
            }
        }
    }
}

#Preview {
    ColorPickerRow(selectedHex: .constant("#4F8EF7")).padding()
}
