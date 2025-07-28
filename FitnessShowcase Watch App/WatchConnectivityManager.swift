//
//  WatchConnectivityManager.swift
//  FitnessShowcase Watch App
//
//  Created by Andrew Cheberyako on 27.07.2025.
//

import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var pendingPlan: WorkoutPlan?
    @Published var isPhoneReachable: Bool = false

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        isPhoneReachable = s.isReachable
    }

    // MARK: Plan reception (unchanged)
    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let data = message["plan"] as? Data,
           let plan = try? JSONDecoder().decode(WorkoutPlan.self, from: data) {
            Task { @MainActor in self.pendingPlan = plan }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let data = applicationContext["plan"] as? Data,
           let plan = try? JSONDecoder().decode(WorkoutPlan.self, from: data) {
            Task { @MainActor in self.pendingPlan = plan }
        }
    }

    // MARK: Reachability
    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isPhoneReachable = session.isReachable }
    }

    // MARK: Foreground-only streaming (simple lane)
    func sendLiveSnapshot(_ snap: LiveSnapshot) {
        guard WCSession.default.isReachable else { return }
        do {
            let data = try JSONEncoder().encode(snap)
            WCSession.default.sendMessageData(data, replyHandler: nil) { error in
                // Drop errors silently; we'll send the next tick
                #if DEBUG
                print("sendMessageData error:", error.localizedDescription)
                #endif
            }
        } catch {
            #if DEBUG
            print("Snapshot encode error:", error.localizedDescription)
            #endif
        }
    }
}
