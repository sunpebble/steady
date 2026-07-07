import Foundation
import HealthKit

@Observable
final class HealthStore {
    private let store = HKHealthStore()
    var readings: [Reading] = []
    var authorized = false
    var isDemo = false
    // preferredUnits 跟随用户在 Health App 里的单位设置，省掉自建单位开关
    private var glucoseUnit: HKUnit = .gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
    private var weightUnit: HKUnit = .gramUnit(with: .kilo)

    private static let quantityTypes: [HKQuantityType] = [
        HKQuantityType(.bloodGlucose), HKQuantityType(.bodyMass),
        HKQuantityType(.heartRate), HKQuantityType(.oxygenSaturation),
        HKQuantityType(.bloodPressureSystolic), HKQuantityType(.bloodPressureDiastolic),
    ]

    @MainActor
    func requestAuthorization() async {
        if isDemo { authorized = true; return }   // demo: 不碰 HK,readings 已由 DemoData 填充
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let types = Set<HKSampleType>(Self.quantityTypes)
        do {
            // HKCorrelationType (bloodPressure) is not a valid authorization type — only its
            // constituent quantity types (already in `types`) can be requested. The correlation
            // type is used only for querying, never for authorization.
            try await store.requestAuthorization(toShare: types, read: types)
            authorized = true
            let preferred = try await store.preferredUnits(for: [HKQuantityType(.bloodGlucose), HKQuantityType(.bodyMass)])
            glucoseUnit = preferred[HKQuantityType(.bloodGlucose)] ?? glucoseUnit
            weightUnit = preferred[HKQuantityType(.bodyMass)] ?? weightUnit
            observeChanges()
            await refresh()
        } catch { /* 未授权就保持空列表，UI 显示引导 */ }
    }

    func unitLabel(for kind: Reading.Kind) -> String {
        switch kind {
        case .bloodPressure: "mmHg"
        case .glucose: glucoseUnit.unitString.contains("mol") ? "mmol/L" : "mg/dL"
        case .weight: weightUnit == .pound() ? "lb" : "kg"
        case .heartRate: "bpm"
        case .oxygen: "%"
        }
    }

    @MainActor
    func save(_ draft: ReadingDraft) async throws {
        if isDemo { insertLocally(Reading(draft: draft)); return }   // demo: 不写 HK
        var metadata: [String: Any] = [:]
        if !draft.note.isEmpty { metadata[Reading.noteKey] = draft.note }
        let sample: HKSample
        switch draft.kind {
        case .bloodPressure:
            let sys = HKQuantitySample(type: HKQuantityType(.bloodPressureSystolic),
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: draft.value),
                start: draft.date, end: draft.date)
            let dia = HKQuantitySample(type: HKQuantityType(.bloodPressureDiastolic),
                quantity: HKQuantity(unit: .millimeterOfMercury(), doubleValue: draft.secondary),
                start: draft.date, end: draft.date)
            sample = HKCorrelation(type: HKCorrelationType(.bloodPressure),
                start: draft.date, end: draft.date, objects: [sys, dia],
                metadata: metadata.isEmpty ? nil : metadata)
        case .glucose:
            if let mealtime = draft.mealtime { metadata[HKMetadataKeyBloodGlucoseMealTime] = mealtime.rawValue }
            sample = HKQuantitySample(type: HKQuantityType(.bloodGlucose),
                quantity: HKQuantity(unit: glucoseUnit, doubleValue: draft.value),
                start: draft.date, end: draft.date, metadata: metadata.isEmpty ? nil : metadata)
        case .weight:
            sample = HKQuantitySample(type: HKQuantityType(.bodyMass),
                quantity: HKQuantity(unit: weightUnit, doubleValue: draft.value),
                start: draft.date, end: draft.date, metadata: metadata.isEmpty ? nil : metadata)
        case .heartRate:
            sample = HKQuantitySample(type: HKQuantityType(.heartRate),
                quantity: HKQuantity(unit: .count().unitDivided(by: .minute()), doubleValue: draft.value),
                start: draft.date, end: draft.date, metadata: metadata.isEmpty ? nil : metadata)
        case .oxygen:
            sample = HKQuantitySample(type: HKQuantityType(.oxygenSaturation),
                quantity: HKQuantity(unit: .percent(), doubleValue: draft.value / 100),
                start: draft.date, end: draft.date, metadata: metadata.isEmpty ? nil : metadata)
        }
        try await store.save(sample)
        await refresh()
    }

    /// 只能删本 app 写入的样本;删别家的 HK 会抛 authorizationDenied,由 UI 提示。
    @MainActor
    func delete(_ reading: Reading) async throws {
        if isDemo { readings.removeAll { $0.id == reading.id }; return }
        let type: HKSampleType = switch reading.kind {
        case .bloodPressure: HKCorrelationType(.bloodPressure)
        case .glucose: HKQuantityType(.bloodGlucose)
        case .weight: HKQuantityType(.bodyMass)
        case .heartRate: HKQuantityType(.heartRate)
        case .oxygen: HKQuantityType(.oxygenSaturation)
        }
        let samples: [HKSample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type,
                predicate: HKQuery.predicateForObject(with: reading.id),
                limit: 1, sortDescriptors: nil) {
                cont.resume(returning: $2 == nil ? ($1 ?? []) : []) }
            store.execute(q)
        }
        guard let sample = samples.first else { await refresh(); return }
        if let corr = sample as? HKCorrelation {
            // 血压 correlation 要连收缩/舒张子样本一起删,否则留下孤儿样本
            try await store.delete(Array(corr.objects) + [corr])
        } else {
            try await store.delete(sample)
        }
        await refresh()
    }

    /// HK 样本不可变,改 = 删旧 + 存新。
    @MainActor
    func update(_ reading: Reading, with draft: ReadingDraft) async throws {
        try await delete(reading)
        try await save(draft)
    }

    @MainActor
    private func insertLocally(_ reading: Reading) {
        readings.append(reading)
        readings.sort { $0.date > $1.date }
    }

    @MainActor
    func refresh() async {
        if isDemo { return }   // demo: 不用 HK 查询覆盖假数据
        // 血压走 correlation 查询；收缩/舒张原始样本不单独出现在时间线
        let types: [HKSampleType] = [HKCorrelationType(.bloodPressure),
            HKQuantityType(.bloodGlucose), HKQuantityType(.bodyMass),
            HKQuantityType(.heartRate), HKQuantityType(.oxygenSaturation)]
        var all: [Reading] = []
        for type in types {
            let samples: [HKSample] = await withCheckedContinuation { cont in
                let q = HKSampleQuery(sampleType: type, predicate: nil, limit: 500,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) {
                    cont.resume(returning: $2 == nil ? ($1 ?? []) : []) }
                store.execute(q)
            }
            all += samples.compactMap { Reading(sample: $0, glucoseUnit: glucoseUnit, weightUnit: weightUnit) }
        }
        readings = all.sorted { $0.date > $1.date }
    }

    // ponytail: 前台 observer 刷新；后台推送投递等有 widget 数据需求再加
    private func observeChanges() {
        for type in Self.quantityTypes {
            let q = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, done, _ in
                Task { @MainActor in await self?.refresh() }
                done()
            }
            store.execute(q)
        }
    }
}
