//
//  DashboardView.swift
//  FitnessShowcase
//
//  Created by Andrew Cheberyako on 27.07.2025.
//

import SwiftUI

struct IOSDashboardView: View {
    @EnvironmentObject private var liveStreamVM: LiveStreamViewModel
    @State private var selected: PlanPreset = .intervals_4x1
    @State private var sending = false

    var body: some View {
        VStack(spacing: 12) {
            VStack{
                Text("Heart rate: \(liveStreamVM.heartRate) bpm")
                Text("Distance: \(liveStreamVM.distanceKm, specifier: "%.2f") km")
                Text("Pace: \(liveStreamVM.paceText)")
                Text("Calories: \(liveStreamVM.kcal, specifier: "%.0f") kcal")
                Text("Connected: \(liveStreamVM.isConnected ? "Yes" : "No")")
            }
            
            Text("Fitness Showcase").font(.title3).bold()
            Text("Choose a workout plan and send to Apple Watch.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // A compact segmented control (good for iPhone)
            Picker("Plan", selection: $selected) {
                ForEach(PlanPreset.allCases) { p in
                    Text(p.title).tag(p)
                }
            }
            .pickerStyle(.inline)

            Button {
                Task {
                    sending = true
                    defer { sending = false }
                    do {
                        let plan = selected.toPlan()
                        try await PhoneConnectivity.shared.updatePlanContext(plan)
                    } catch {
                        print("Send failed:", error.localizedDescription)
                    }
                }
            } label: {
                Text(sending ? "Sending…" : "Send to Watch")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            // Optional: short preview of the intervals
            PlanPreviewView(plan: selected.toPlan())
                .padding(.top, 8)
        }
        .padding()
        .onAppear { PhoneConnectivity.shared.activate() }
    }
}

private struct PlanPreviewView: View {
    let plan: WorkoutPlan
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.displayTitle).font(.headline)
            let total = Int(plan.intervals.map(\.duration).reduce(0, +) / 60)
            Text("Total \(total) min • \(plan.sport.capitalized)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
