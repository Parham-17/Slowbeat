import Foundation
import HealthKit
import Observation

@Observable
final class HealthService {
    enum Access {
        case unknown, denied, granted, unavailable
    }

    private let store = HKHealthStore()
    private let hrType: HKQuantityType? = HKQuantityType.quantityType(forIdentifier: .heartRate)

    var access: Access = .unknown
    var latestHeartRate: Double?
    var latestHeartRateAt: Date?

    init() {
        if HKHealthStore.isHealthDataAvailable() == false {
            access = .unavailable
        }
    }

    /// Asks for *read-only* heart rate access. We never write.
    @discardableResult
    func requestAccess() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(), let hrType else {
            access = .unavailable
            return false
        }
        do {
            try await store.requestAuthorization(toShare: [], read: [hrType])
            // Authorization status for *read* types is not exposed accurately for privacy reasons —
            // we infer access by attempting a query. We mark as granted optimistically.
            access = .granted
            return true
        } catch {
            access = .denied
            return false
        }
    }

    /// Loads the most recent heart rate sample, if any exists in the last 24h.
    func loadLatest() async {
        guard let hrType else { return }
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now.addingTimeInterval(-86400)
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: .strictEndDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let result: (Double?, Date?) = await withCheckedContinuation { cont in
            let query = HKSampleQuery(
                sampleType: hrType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    cont.resume(returning: (nil, nil))
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                cont.resume(returning: (bpm, sample.endDate))
            }
            store.execute(query)
        }
        latestHeartRate = result.0
        latestHeartRateAt = result.1
    }

    /// True when the latest reading is fresh enough to surface as context.
    var hasFreshReading: Bool {
        guard let at = latestHeartRateAt else { return false }
        return Date().timeIntervalSince(at) < 60 * 60 // 1h
    }
}
