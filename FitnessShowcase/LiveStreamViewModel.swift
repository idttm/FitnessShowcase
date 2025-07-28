//
//  LiveStreamViewModel.swift
//  FitnessShowcase
//
//  Created by Andrew Cheberyako on 27.07.2025.
//

import Foundation
import SwiftUI
import Combine

final class LiveStreamViewModel: ObservableObject {
    @Published var planTitle: String? = nil
    @Published var heartRate: Int = 0
    @Published var distanceKm: Double = 0
    @Published var paceText: String = "--:--"
    @Published var kcal: Double = 0
    @Published var isConnected: Bool = false

    private var lastSeq: Int = -1

    init(connectivity: PhoneConnectivity = .shared) {
        connectivity.onSnapshot = { [weak self] snap in
            guard let self else { return }
            // ignore out-of-order/duplicates
            guard snap.seq > self.lastSeq else { return }
            self.lastSeq = snap.seq

            DispatchQueue.main.async {
                self.planTitle = snap.title ?? self.planTitle
                self.heartRate = snap.hr ?? self.heartRate
                if let m = snap.dist { self.distanceKm = m / 1000.0 }
                self.kcal = snap.kcal ?? self.kcal
                self.paceText = Self.pace(fromSpeed: snap.spd)
            }
        }
        connectivity.activate()
        self.isConnected = connectivity.isWatchReachable
        // If you want live connection state updates, observe PhoneConnectivity.shared.$isWatchReachable from your View
    }

    private static func pace(fromSpeed spd: Double?) -> String {
        guard let v = spd, v > 0 else { return "--:--" }
        let secPerKm = 1000.0 / v
        let m = Int(secPerKm) / 60
        let s = Int(secPerKm) % 60
        return String(format: "%d:%02d", m, s)
    }
}
