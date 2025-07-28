import Foundation
import WatchConnectivity
import Combine

final class PhoneConnectivity: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = PhoneConnectivity()
    private override init() {}

    @Published var isWatchReachable: Bool = false

    var onSnapshot: ((LiveSnapshot) -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
        isWatchReachable = s.isReachable
    }

    @MainActor
    func sendPlan(_ plan: WorkoutPlan) async throws {
        let data = try JSONEncoder().encode(plan)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            guard WCSession.default.isReachable else {
                cont.resume(throwing: NSError(domain: "WCSession", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Watch not reachable"]))
                return
            }
            WCSession.default.sendMessage(["plan": data], replyHandler: { _ in
                cont.resume()
            }, errorHandler: { error in
                cont.resume(throwing: error)
            })
        }
    }

    @MainActor
    func updatePlanContext(_ plan: WorkoutPlan) async throws {
        let data = try JSONEncoder().encode(plan)
        guard WCSession.default.activationState == .activated else {
            throw NSError(domain: "WCSession", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "WCSession not activated"])
        }
        try WCSession.default.updateApplicationContext(["plan": data])
    }

    func session(_ session: WCSession, didReceiveMessageData data: Data) {
        guard let snap = try? JSONDecoder().decode(LiveSnapshot.self, from: data) else { return }
        onSnapshot?(snap)
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.isWatchReachable = session.isReachable }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
    func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isWatchReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
    }
}
