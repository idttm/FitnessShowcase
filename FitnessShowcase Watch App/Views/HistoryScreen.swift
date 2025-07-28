import SwiftUI

struct HistoryScreen: View {
    @ObservedObject var vm: WorkoutViewModel

    var body: some View {
        Group {
            if $vm.summaries.isEmpty {
                VStack(spacing: 6) {
                    Text("No recent workouts")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Start one from the Workout tab.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Recent") {
                        ForEach(vm.summaries) { s in HistoryRow(item: s) }
                    }
                }
            }
        }
        .onAppear { Task { await vm.loadRecent() } }
        // Optional: refresh after a workout stops
        .onChange(of: vm.isRunning) { _, nowRunning in
            if !nowRunning {
                Task { await vm.loadRecent() }
            }
        }
    }
}
