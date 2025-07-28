import Foundation
import HealthKit
import WatchKit

// MARK: - Toggle mocks when needed
public let FORCE_USE_MOCK = false

// MARK: - Data Snapshots & Events
public struct WorkoutMetrics: Sendable {
    public var timestamp: Date = .init()
    public var heartRate: Double?
    public var activeEnergy: Double?      // kilocalories
    public var distance: Double?          // meters
    public var runningSpeed: Double?      // m/s
    public var strideLength: Double?      // meters
    public var cyclingSpeed: Double?      // m/s (watchOS 10+ with sensors)
    public var cyclingPower: Double?      // watts
    public var cyclingCadence: Double?    // rpm
}

public struct WorkoutEventInfo: Sendable {
    public let date: Date
    public let type: HKWorkoutEventType
}

// MARK: - Engine protocol
public protocol WorkoutEngine: AnyObject {
    func requestAuthorization() async throws
    func start(plan: WorkoutPlan) async
    func stop() async
    func heartRateStream() -> AsyncStream<Double>
    func metricsStream() -> AsyncStream<WorkoutMetrics>
    func eventsStream() -> AsyncStream<WorkoutEventInfo>
    func recentWorkouts(limit: Int) async throws -> [WorkoutSummary]
}

// MARK: - Real HealthKit implementation
final class RealWorkoutEngine: NSObject, WorkoutEngine, HKLiveWorkoutBuilderDelegate {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var hrContinuation: AsyncStream<Double>.Continuation?
    private var metricsContinuation: AsyncStream<WorkoutMetrics>.Continuation?
    private var eventsContinuation: AsyncStream<WorkoutEventInfo>.Continuation?
    private var latest = WorkoutMetrics()

    // Optional: lightweight persistence hook (SwiftData store will conform to this protocol)
    private let saver: WorkoutSummarySaving?

    init(saver: WorkoutSummarySaving? = nil) {
        self.saver = saver
        super.init()
    }

    // Authorization covering common metrics; add guarded availability for newer cycling types.
    func requestAuthorization() async throws {
        var rw: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .runningSpeed)!,
            HKQuantityType.quantityType(forIdentifier: .runningStrideLength)!
        ]
        if #available(watchOS 10.0, *) {
            if let spd = HKQuantityType.quantityType(forIdentifier: .cyclingSpeed) { rw.insert(spd) }
            if let pwr = HKQuantityType.quantityType(forIdentifier: .cyclingPower) { rw.insert(pwr) }
            if let cad = HKQuantityType.quantityType(forIdentifier: .cyclingCadence) { rw.insert(cad) }
        }
        try await healthStore.requestAuthorization(toShare: rw, read: rw)
    }

    func start(plan: WorkoutPlan) async {
        do {
            let cfg = HKWorkoutConfiguration()
            cfg.activityType = plan.sport.lowercased() == "running" ? .running : .other
            cfg.locationType = .outdoor
            session = try HKWorkoutSession(healthStore: healthStore, configuration: cfg)
            builder = session!.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: cfg)
            builder?.delegate = self
            session?.startActivity(with: Date())
            try await builder?.beginCollection(withStart: Date()) { _, _ in }
        } catch {
            print("Start failed:", error.localizedDescription)
        }
    }

    func stop() async {
        session?.end()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            builder?.endCollection(withEnd: Date()) { _, _ in
                self.builder?.finishWorkout { workout, _ in
                    if let w = workout {
                        Task { await self.saveSummary(from: w) }
                    }
                    cont.resume()
                }
            }
        }
        hrContinuation?.finish()
        metricsContinuation?.finish()
        eventsContinuation?.finish()
    }

    func heartRateStream() -> AsyncStream<Double> {
        AsyncStream { cont in self.hrContinuation = cont }
    }

    func metricsStream() -> AsyncStream<WorkoutMetrics> {
        AsyncStream { cont in self.metricsContinuation = cont }
    }

    func eventsStream() -> AsyncStream<WorkoutEventInfo> {
        AsyncStream { cont in self.eventsContinuation = cont }
    }

    // MARK: - HKLiveWorkoutBuilderDelegate
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        guard let ev = workoutBuilder.workoutEvents.last else { return }
        eventsContinuation?.yield(.init(date: ev.date, type: ev.type))
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        let unitBPM = HKUnit(from: "count/min")
        let unitKCal = HKUnit.kilocalorie()
        let unitM = HKUnit.meter()
        let unitMS = HKUnit.meter().unitDivided(by: .second())

        if let t = HKQuantityType.quantityType(forIdentifier: .heartRate), types.contains(t),
           let stats = workoutBuilder.statistics(for: t),
           let v = stats.mostRecentQuantity()?.doubleValue(for: unitBPM) {
            latest.heartRate = v
            hrContinuation?.yield(v)
        }
        if let t = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned), types.contains(t),
           let stats = workoutBuilder.statistics(for: t),
           let v = stats.sumQuantity()?.doubleValue(for: unitKCal) {
            latest.activeEnergy = v
        }
        if let t = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning), types.contains(t),
           let stats = workoutBuilder.statistics(for: t),
           let v = stats.sumQuantity()?.doubleValue(for: unitM) {
            latest.distance = v
        }
        if let t = HKQuantityType.quantityType(forIdentifier: .runningSpeed), types.contains(t),
           let stats = workoutBuilder.statistics(for: t),
           let v = stats.mostRecentQuantity()?.doubleValue(for: unitMS) {
            latest.runningSpeed = v
        }
        if let t = HKQuantityType.quantityType(forIdentifier: .runningStrideLength), types.contains(t),
           let stats = workoutBuilder.statistics(for: t),
           let v = stats.mostRecentQuantity()?.doubleValue(for: unitM) {
            latest.strideLength = v
        }
        if #available(watchOS 10.0, *) {
            if let t = HKQuantityType.quantityType(forIdentifier: .cyclingSpeed), types.contains(t),
               let stats = workoutBuilder.statistics(for: t),
               let v = stats.mostRecentQuantity()?.doubleValue(for: unitMS) {
                latest.cyclingSpeed = v
            }
            if let t = HKQuantityType.quantityType(forIdentifier: .cyclingPower), types.contains(t),
               let stats = workoutBuilder.statistics(for: t),
               let v = stats.mostRecentQuantity()?.doubleValue(for: .watt()) {
                latest.cyclingPower = v
            }
            if let t = HKQuantityType.quantityType(forIdentifier: .cyclingCadence), types.contains(t),
               let stats = workoutBuilder.statistics(for: t),
               let v = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) {
                latest.cyclingCadence = v
            }
        }

        latest.timestamp = Date()
        metricsContinuation?.yield(latest)
    }

    // MARK: - History
    func recentWorkouts(limit: Int) async throws -> [WorkoutSummary] {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: nil, limit: limit, sortDescriptors: [sort]) {
                _, samples, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            self.healthStore.execute(q)
        }
        var arr: [WorkoutSummary] = []
        for w in workouts {
            let avg = try await averageHeartRate(for: w)
            arr.append(.init(id: w.uuid.uuidString, date: w.startDate, duration: w.duration, averageHR: avg))
        }
        return arr
    }

    private func averageHeartRate(for workout: HKWorkout) async throws -> Double? {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let pred = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred, options: .discreteAverage) { _, result, error in
                if let error { cont.resume(throwing: error); return }
                let unit = HKUnit(from: "count/min")
                let value = result?.averageQuantity()?.doubleValue(for: unit)
                cont.resume(returning: value)
            }
            self.healthStore.execute(q)
        }
    }

    // Save minimal summary via injected store
    private func saveSummary(from workout: HKWorkout) async {
        guard let saver = saver else { return }
        let summary = WorkoutSummary(id: workout.uuid.uuidString, date: workout.startDate, duration: workout.duration, averageHR: try? await averageHeartRate(for: workout))
        await saver.save(summary: summary)
    }
}

// MARK: - Mock implementation for simulator
final class MockWorkoutEngine: WorkoutEngine {
    private var hrCont: AsyncStream<Double>.Continuation?
    private var metricsCont: AsyncStream<WorkoutMetrics>.Continuation?
    private var eventsCont: AsyncStream<WorkoutEventInfo>.Continuation?

    private var tickingTask: Task<Void, Never>?
    private var isRunning = false
    private var mockStore: [WorkoutSummary] = []

    func requestAuthorization() async throws { /* no-op */ }

    func start(plan: WorkoutPlan) async {
        guard !isRunning else { return }
        isRunning = true
        var hr = 110.0
        var distance = 0.0
        var energy = 0.0
        var speed = 2.8 // m/s ~ 10 km/h

        tickingTask = Task {
            while !Task.isCancelled && isRunning {
                // Random walk
                hr = max(85, min(175, hr + Double(Int.random(in: -2...3))))
                speed = max(1.2, min(4.5, speed + Double(Int.random(in: -1...1)) * 0.1))
                distance += speed * 1.0 // per second
                energy += 0.17 // ~0.17 kcal/s at light run (just for demo)

                hrCont?.yield(hr)
                metricsCont?.yield(.init(timestamp: .init(), heartRate: hr, activeEnergy: energy, distance: distance, runningSpeed: speed, strideLength: 1.1, cyclingSpeed: nil, cyclingPower: nil, cyclingCadence: nil))

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        eventsCont?.yield(.init(date: .init(), type: .segment))
    }

    func stop() async {
        guard isRunning else { return }
        isRunning = false
        tickingTask?.cancel(); tickingTask = nil
        hrCont?.finish(); metricsCont?.finish(); eventsCont?.yield(.init(date: .init(), type: .pause)); eventsCont?.finish()

        let avg = 130.0 + Double(Int.random(in: -10...10))
        mockStore.insert(WorkoutSummary(id: UUID().uuidString, date: Date(), duration: 10*60, averageHR: avg), at: 0)
        if mockStore.count > 10 { mockStore.removeLast() }
    }

    func heartRateStream() -> AsyncStream<Double> { AsyncStream { self.hrCont = $0 } }
    func metricsStream() -> AsyncStream<WorkoutMetrics> { AsyncStream { self.metricsCont = $0 } }
    func eventsStream() -> AsyncStream<WorkoutEventInfo> { AsyncStream { self.eventsCont = $0 } }

    func recentWorkouts(limit: Int) async throws -> [WorkoutSummary] { Array(mockStore.prefix(limit)) }
}

// Engine chooser
#if targetEnvironment(simulator)
let DEFAULT_USE_MOCK = true
#else
let DEFAULT_USE_MOCK = false
#endif

public func makeEngine(saver: WorkoutSummarySaving? = nil) -> WorkoutEngine {
    if FORCE_USE_MOCK || DEFAULT_USE_MOCK { return MockWorkoutEngine() }
    return RealWorkoutEngine(saver: saver)
}

// MARK: - Optional persistence protocol
public protocol WorkoutSummarySaving {
    func save(summary: WorkoutSummary) async
}
