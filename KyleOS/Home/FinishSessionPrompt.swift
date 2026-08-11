import SwiftUI

/// PRD §5.4: "At the end of a relevant session, Kyle OS asks how complete the current stage
/// is." Intentionally minimal — one slider, no design-system work (final visual identity is
/// Decision Gate C, deferred to V1.0).
struct FinishSessionPrompt: View {
    @Binding var progress: Double
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How complete is this stage now?")
                .font(.headline)
            HStack {
                Slider(value: $progress, in: 0...100, step: 1)
                Text("\(Int(progress))%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Finish Session") {
                    onConfirm()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }
}

#Preview {
    FinishSessionPrompt(progress: .constant(45), onConfirm: {})
}
