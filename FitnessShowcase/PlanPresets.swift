//
//  PlanPresets.swift
//  FitnessShowcase
//
//  Created by Andrew Cheberyako on 27.07.2025.
//

import Foundation

enum PlanPreset: String, CaseIterable, Identifiable {
    case easyRun
    case intervals_4x1
    case tempo_20min
    case longRun_60
    var id: String { rawValue }

    var title: String {
        switch self {
        case .easyRun: return "Easy Run 20 min"
        case .intervals_4x1: return "4×(5:00 run / 1:00 rest)"
        case .tempo_20min: return "Tempo 20 min"
        case .longRun_60: return "Long Run 60 min"
        }
    }

    func toPlan() -> WorkoutPlan {
        switch self {
        case .easyRun:
            return .init(sport: "running",
                         intervals: [.init(type: "run", duration: TimeInterval(20*60))],
                         title: title)

        case .intervals_4x1:
            var arr: [Interval] = []
            for _ in 0..<4 {
                arr.append(.init(type: "run",  duration: 5*60))
                arr.append(.init(type: "rest", duration: 60))
            }
            return .init(sport: "running", intervals: arr, title: title)

        case .tempo_20min:
            return .init(sport: "running",
                         intervals: [
                            .init(type: "run", duration: TimeInterval(5*60)),     // warm-up
                            .init(type: "run", duration: TimeInterval(20*60)),    // tempo
                            .init(type: "rest", duration: TimeInterval(2*60))     // cool-down (walk)
                         ],
                         title: title)

        case .longRun_60:
            return .init(sport: "running",
                         intervals: [.init(type: "run", duration: TimeInterval(60*60))],
                         title: title)
        }
    }
}
