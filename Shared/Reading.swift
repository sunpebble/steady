import Foundation
import HealthKit

struct Reading: Identifiable, Equatable {
    /// 备注塞进 HK sample metadata 的自定义 key。定义在 Shared,widget/watch target 也编译。
    static let noteKey = "com.sunpebble.steady.note"

    enum Kind: String, CaseIterable, Identifiable {
        case bloodPressure, glucose, weight, heartRate, oxygen
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .bloodPressure: String(localized: "Blood pressure")
            case .glucose: String(localized: "Blood glucose")
            case .weight: String(localized: "Weight")
            case .heartRate: String(localized: "Heart rate")
            case .oxygen: String(localized: "Blood oxygen")
            }
        }
        var systemImage: String {
            switch self {
            case .bloodPressure: "heart.text.square"
            case .glucose: "drop"
            case .weight: "scalemass"
            case .heartRate: "waveform.path.ecg"
            case .oxygen: "lungs"
            }
        }
    }

    enum Mealtime: Int, CaseIterable, Identifiable {
        case fasting = 1, afterMeal = 2   // rawValue 对齐 HKBloodGlucoseMealTime
        var id: Int { rawValue }
        var label: String {
            self == .fasting ? String(localized: "Fasting") : String(localized: "After meal")
        }
    }

    let id: UUID
    let kind: Kind
    let date: Date
    let value: Double          // 血压时 = 收缩压
    let secondary: Double?     // 血压时 = 舒张压
    let mealtime: Mealtime?    // 仅血糖
    let note: String?

    /// 展示字符串，如 "128/84"、"105"。单位标签由调用方拼。
    var display: String {
        let v = value.formatted(.number.precision(.fractionLength(0...1)))
        if let secondary {
            return "\(v)/\(secondary.formatted(.number.precision(.fractionLength(0))))"
        }
        return v
    }
}

extension Reading {
    /// HKSample → Reading 纯映射。未知类型返回 nil。
    init?(sample: HKSample, glucoseUnit: HKUnit, weightUnit: HKUnit) {
        let note = sample.metadata?[Reading.noteKey] as? String
        if let corr = sample as? HKCorrelation, corr.correlationType == HKCorrelationType(.bloodPressure) {
            func value(_ id: HKQuantityTypeIdentifier) -> Double? {
                (corr.objects(for: HKQuantityType(id)).first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .millimeterOfMercury())
            }
            guard let sys = value(.bloodPressureSystolic), let dia = value(.bloodPressureDiastolic)
            else { return nil }
            self.init(id: corr.uuid, kind: .bloodPressure, date: corr.startDate,
                      value: sys, secondary: dia, mealtime: nil, note: note)
            return
        }
        guard let qs = sample as? HKQuantitySample else { return nil }
        let kind: Kind
        let value: Double
        switch qs.quantityType {
        case HKQuantityType(.bloodGlucose):
            kind = .glucose; value = qs.quantity.doubleValue(for: glucoseUnit)
        case HKQuantityType(.bodyMass):
            kind = .weight; value = qs.quantity.doubleValue(for: weightUnit)
        case HKQuantityType(.heartRate):
            kind = .heartRate
            value = qs.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        case HKQuantityType(.oxygenSaturation):
            kind = .oxygen; value = qs.quantity.doubleValue(for: .percent()) * 100
        default:
            return nil
        }
        let mealtime = (qs.metadata?[HKMetadataKeyBloodGlucoseMealTime] as? Int)
            .flatMap(Mealtime.init(rawValue:))
        self.init(id: qs.uuid, kind: kind, date: qs.startDate,
                  value: value, secondary: nil, mealtime: mealtime, note: note)
    }
}

struct ReadingDraft {
    var kind: Reading.Kind
    var date: Date = .now
    var value: Double = 0
    var secondary: Double = 0          // 仅血压（舒张压）
    var mealtime: Reading.Mealtime? = nil
    var note: String = ""
}
