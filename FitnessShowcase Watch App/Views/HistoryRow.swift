import SwiftUI

struct HistoryRow: View {
    let item: WorkoutSummary

    private var durationMinutes: Int { Int(item.duration / 60) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // Date + time on one line
                (Text(item.date, style: .date) + Text(" ") + Text(item.date, style: .time))
                    .font(.caption)
                Text("Duration \(durationMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let avg = item.averageHR {
                Text("\(Int(avg)) bpm")
                    .font(.caption)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}
