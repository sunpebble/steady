import Foundation
import SwiftData

enum LaunchArgs {
    static let isDemoSeed = CommandLine.arguments.contains("-seedDemo")
}

enum DemoData {
    /// 演示数据:测量填 health.readings(不写 HK),用药/症状写内存容器,目标范围走内存覆盖。
    @MainActor
    static func seed(into health: HealthStore, ctx: ModelContext) {
        let now = Date.now
        seedReadings(into: health, now: now)
        seedMedsAndSymptoms(into: ctx, now: now)
        SettingsStore.demoRanges = [
            .bloodPressure: 90...130,   // 收缩压 mmHg
            .glucose: 80...130,          // mg/dL
            .weight: 65...75,            // kg
        ]
    }

    private static func seedReadings(into health: HealthStore, now: Date) {
        let cal = Calendar.current
        var readings: [Reading] = []
        for dayOffset in stride(from: 0, through: 90, by: 3) {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: now)!
            readings.append(Reading(id: UUID(), kind: .bloodPressure, date: date,
                value: Double.random(in: 118...145), secondary: Double.random(in: 76...92),
                mealtime: nil, note: nil))
            readings.append(Reading(id: UUID(), kind: .glucose, date: date,
                value: Double.random(in: 85...140), secondary: nil,
                mealtime: dayOffset % 2 == 0 ? .fasting : .afterMeal, note: nil))
            readings.append(Reading(id: UUID(), kind: .weight, date: date,
                value: Double.random(in: 68...72), secondary: nil, mealtime: nil, note: nil))
            readings.append(Reading(id: UUID(), kind: .heartRate, date: date,
                value: Double.random(in: 62...78), secondary: nil, mealtime: nil, note: nil))
            readings.append(Reading(id: UUID(), kind: .oxygen, date: date,
                value: Double.random(in: 95...98), secondary: nil, mealtime: nil, note: nil))
        }
        health.readings = readings.sorted { $0.date > $1.date }
    }

    private static func seedMedsAndSymptoms(into ctx: ModelContext, now: Date) {
        let cal = Calendar.current
        let metformin = Medication(name: "Metformin", dosage: "500mg", times: [8 * 60, 20 * 60])
        let lisinopril = Medication(name: "Lisinopril", dosage: "10mg", times: [8 * 60])
        ctx.insert(metformin)
        ctx.insert(lisinopril)
        let today8 = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now)!
        ctx.insert(MedLog(date: today8, slot: 8 * 60, taken: true, medication: metformin))
        ctx.insert(MedLog(date: today8, slot: 8 * 60, taken: true, medication: lisinopril))
        ctx.insert(SymptomEntry(name: "Headache", severity: 2,
            date: cal.date(byAdding: .hour, value: -6, to: now)!, note: "after lunch"))
        ctx.insert(SymptomEntry(name: "Fatigue", severity: 1,
            date: cal.date(byAdding: .day, value: -1, to: now)!, note: ""))
        ctx.insert(SymptomEntry(name: "Dizziness", severity: 3,
            date: cal.date(byAdding: .day, value: -3, to: now)!, note: "morning"))
        try? ctx.save()
    }
}
