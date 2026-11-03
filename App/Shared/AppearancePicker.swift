import SwiftUI

/// Icon grid plus color swatches for a tracker.
struct AppearancePicker: View {
    @Binding var icon: String
    @Binding var colorName: String
    var icons: [String] = TrackerPalette.medicineIcons

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    var body: some View {
        let color = TrackerPalette.color(named: colorName)
        VStack(spacing: 16) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(icons, id: \.self) { name in
                    let isSelected = name == icon
                    Button {
                        icon = name
                    } label: {
                        Image(systemName: name)
                            .font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundStyle(isSelected ? Color.white : color)
                            .background(isSelected ? color : color.opacity(0.15), in: .rect(cornerRadius: 10))
                    }
                    // Borderless: several buttons in one Form row must not all fire on a row tap.
                    .buttonStyle(.borderless)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(TrackerPalette.colorNames, id: \.self) { name in
                    Button {
                        colorName = name
                    } label: {
                        Circle()
                            .fill(TrackerPalette.color(named: name))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if name == colorName {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(name)
                    .accessibilityAddTraits(name == colorName ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
