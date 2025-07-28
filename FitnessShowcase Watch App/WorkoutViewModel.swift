import Foundation
import SwiftUI
import Combine
import HealthKit

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var heartRate: Int = 0
    @Published var isRunning: Bool = false
    @Published var summaries: [WorkoutSummary] = []
    @Published var distance: Double = 0        // meters
    @Published var speedMps: Double? = nil     // meters/second (nil if unknown)
    @Published var eventBadge: String? = nil   // transient UI badge, e.g., "Paused"
    
    private let engine: WorkoutEngine
    private var hrTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?
    private var eventsTask: Task<Void, Never>?
    private var sequence = 0
    
    private(set) var currentPlan: WorkoutPlan? = nil
    
    init(engine: WorkoutEngine) { self.engine = engine }
    
    func authorizeIfNeeded() async {
        do { try await engine.requestAuthorization() } catch { print("Auth error:", error.localizedDescription) }
    }
    
    func start(plan: WorkoutPlan) {
        Task {
            self.currentPlan = plan
            await engine.start(plan: plan)
            isRunning = true
            
            startHeartRateStream()
            startEventsStream()
            startMetricsStream()
        }
    }
    
    func stop() {
        Task {
            await engine.stop()
            isRunning = false
            self.currentPlan = nil
            self.heartRate = 0
            self.summaries = []
            self.distance = 0
            self.speedMps = nil
            self.eventBadge = nil
            
            hrTask?.cancel()
            hrTask = nil
            metricsTask?.cancel()
            metricsTask = nil
            eventsTask?.cancel()
            eventsTask = nil
            sequence = 0
            await loadRecent()
        }
    }
    
    func loadRecent() async {
        do { self.summaries = try await engine.recentWorkouts(limit: 5) }
        catch { print("Recent error:", error.localizedDescription) }
    }
    
    private func startHeartRateStream() {
        hrTask?.cancel()
        hrTask = Task {
            for await hr in engine.heartRateStream() {
                self.heartRate = Int(hr.rounded())
            }
        }
    }
    
    private func startEventsStream() {
        eventsTask?.cancel()
        eventsTask = Task {
            for await e in engine.eventsStream() {
                switch e.type {
                case .pause:  self.eventBadge = "Paused"
                case .resume: self.eventBadge = "Resumed"
                case .segment: self.eventBadge = "Segment"
                default: self.eventBadge = nil
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self.eventBadge = nil
            }
        }
    }
    
    private func startMetricsStream() {
        metricsTask?.cancel()
        metricsTask = Task {
            for await m in engine.metricsStream() {
                // UI updates
                self.distance = m.distance ?? 0
                self.speedMps = m.runningSpeed
                
                // Foreground-only: stream to iPhone if reachable
                if WatchConnectivityManager.shared.isPhoneReachable {
                    let snap = LiveSnapshot(
                        ts: Date().unixMillis,
                        seq: { sequence += 1; return sequence }(),
                        hr: Int((m.heartRate ?? 0).rounded()),
                        dist: m.distance,
                        spd: m.runningSpeed,
                        kcal: m.activeEnergy,
                        state: 1,
                        title: currentPlan?.displayTitle
                    )
                    WatchConnectivityManager.shared.sendLiveSnapshot(snap)
                }
            }
        }
    }
    
    private func pendingPlanTitle() -> String? {
        // If you pass the plan into start(plan:), keep it around in the VM
        // Or read WatchConnectivityManager.shared.pendingPlan?.displayTitle
        return nil
    }
}
