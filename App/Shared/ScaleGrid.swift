import SwiftUI

/// 1–10 rating as a 2×5 grid of buttons (D12): one tap, no slider fiddling.
struct ScaleGrid: View {
    let range: ClosedRange<Int>
    let selection: Int?
    let color: Color
    let onPick: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(range), id: \.self) { number in
                    let isSelected = number == selection
                    Button {
                        onPick(number)
                    } label: {
                        Text("\(number)")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                            .background(isSelected ? color : color.opacity(0.18), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(number) of \(range.upperBound)")
                }
            }
            HStack {
                Text("\(range.lowerBound) = low")
                Spacer()
                Text("\(range.upperBound) = high")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}
