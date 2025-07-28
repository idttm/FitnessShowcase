//
//  WatchContentView.swift
//  FitnessShowcase Watch App
//
//  Created by Andrew Cheberyako on 27.07.2025.
//

import SwiftUI

struct WorkoutScreen: View {
    @ObservedObject var vm: WorkoutViewModel
    var pendingPlan: WorkoutPlan?

    // Local formatting helpers
    private func kmString(_ meters: Double) -> String {
        let km = meters / 1000
        return km.formatted(.number.precision(.fractionLength(2)))
    }

    private func paceString(from speedMps: Double?) -> String {
        guard let v = speedMps, v > 0 else { return "--:--" }
        let secPerKm = 1000 / v
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func speedKmh(_ speedMps: Double?) -> String {
        guard let v = speedMps else { return "--" }
        return (v * 3.6).formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        ZStack(alignment: .top) {
            
            VStack(spacing: 0) {
                
                PlanBadge(text: pendingPlan?.displayTitle ?? "WorkoutPlan")
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // HR block
                VStack(spacing: 0) {
                    Text("HR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(vm.heartRate)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .transaction { t in
                            t.animation = .default
                        }
                    Text("bpm").font(.caption2).foregroundStyle(.secondary)
                }
                
                // Metrics grid
                HStack(spacing: 8) {
                    MetricTile(title: "Distance",
                               value: kmString(vm.distance),
                               unit: "km")
                    
                    // Show pace if running speed is available; otherwise show speed
                    if let speed = vm.speedMps, speed > 0 {
                        MetricTile(title: "Pace",
                                   value: paceString(from: speed),
                                   unit: "min/km")
                    } else {
                        MetricTile(title: "Speed",
                                   value: speedKmh(vm.speedMps),
                                   unit: "km/h")
                    }
                }
                
                // Controls
                if vm.isRunning {
                    Button {
                        // light haptic feedback (optional)
                        WKInterfaceDevice.current().play(.stop)
                        vm.stop()
                    } label: { Text("Stop") }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button {
                        WKInterfaceDevice.current().play(.start)
                        let plan = pendingPlan ?? .sample
                        vm.start(plan: plan)
                    } label: { Text("Start") }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            
            if let badge = vm.eventBadge {
                Text(badge)
                    .font(.caption2)
                    .padding(.horizontal, 8).padding(.vertical, 10)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .navigationTitle(pendingPlan?.title ?? "PlanBadge")
        .animation(.easeInOut(duration: 0.2), value: vm.eventBadge)
        .onAppear { Task { await vm.authorizeIfNeeded() } }
    }
}
