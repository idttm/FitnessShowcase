//
//  Models.swift
//  FitnessShowcase
//
//  Created by Andrew Cheberyako on 27.07.2025.
//

import Foundation

public struct Interval: Codable, Sendable, Equatable {
    public let type: String    // "run" | "rest"
    public let duration: TimeInterval
    public init(type: String, duration: TimeInterval) {
        self.type = type; self.duration = duration
    }
}

public struct WorkoutPlan: Codable, Sendable, Equatable {
    public let sport: String           // e.g. "running"
    public let intervals: [Interval]
    public let title: String?          // <- NEW (optional)

    public init(sport: String, intervals: [Interval], title: String? = nil) {
        self.sport = sport
        self.intervals = intervals
        self.title = title
    }

    public static var sample: WorkoutPlan {
        .init(sport: "running",
              intervals: [
                .init(type: "run",  duration: 300),
                .init(type: "rest", duration: 60),
                .init(type: "run",  duration: 300)
              ],
              title: "2×(5:00 run / 1:00 rest)")
    }
}

// Nicely formatted fallback when title is nil
public extension WorkoutPlan {
    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        let runs = intervals.filter { $0.type == "run" }
        let rests = intervals.filter { $0.type == "rest" }
        let total = Int(intervals.map(\.duration).reduce(0, +) / 60)
        let sportCap = sport.capitalized
        if !runs.isEmpty && runs.count == rests.count, let r = runs.first, let s = rests.first {
            func mmss(_ t: TimeInterval) -> String {
                let m = Int(t) / 60, s = Int(t) % 60
                return String(format: "%d:%02d", m, s)
            }
            return "\(runs.count)×(\(mmss(r.duration)) run / \(mmss(s.duration)) rest) • \(sportCap)"
        }
        return "\(sportCap) • \(total) min"
    }
}

public struct WorkoutSummary: Identifiable, Sendable {
    public let id: String
    public let date: Date
    public let duration: TimeInterval
    public let averageHR: Double?
    public init(id: String, date: Date, duration: TimeInterval, averageHR: Double?) {
        self.id = id; self.date = date; self.duration = duration; self.averageHR = averageHR
    }
}

public struct LiveSnapshot: Codable, Sendable {
    public var value: Int = 1                 // schema version
    public let ts: Int64                  // Unix ms
    public let seq: Int                   // monotonic counter
    public let hr: Int?                   // bpm
    public let dist: Double?              // meters (total)
    public let spd: Double?               // m/s (running speed)
    public let kcal: Double?              // active energy (kcal)
    public let state: Int                 // 0 idle, 1 running, 2 paused
    public let title: String?             // plan title (optional)
}

public extension Date {
    var unixMillis: Int64 { Int64(timeIntervalSince1970 * 1000) }
}
