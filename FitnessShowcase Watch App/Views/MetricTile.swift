import SwiftUI

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold().monospacedDigit()
                .contentTransition(.numericText())
                .transaction { t in
                    t.animation = .default
                }
            Text(unit).font(.caption2).foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .transaction { t in
                    t.animation = .default
                }
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
    }
}
