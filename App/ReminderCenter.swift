import Foundation
import UserNotifications

struct MeasurementReminder: Codable, Equatable {
    var hour: Int = 8
    var minute: Int = 0
    var kinds: [Reading.Kind.RawValue] = []
}

enum ReminderCenter {
    /// 全量重排。数据量级是个位数药物 x 个位数时段，清空重建最简单也最不容易漂移。
    static func sync(meds: [Medication], measurement: MeasurementReminder?) async {
        let center = UNUserNotificationCenter.current()
        guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true
        else { return }
        center.removeAllPendingNotificationRequests()
        for med in meds where !med.archived {
            for slot in med.times {
                let content = UNMutableNotificationContent()
                content.title = med.name
                content.body = String(localized: "Time for \(med.dosage.isEmpty ? med.name : med.dosage).")
                content.sound = .default
                var comps = DateComponents()
                comps.hour = slot / 60
                comps.minute = slot % 60
                try? await center.add(UNNotificationRequest(
                    identifier: "med.\(med.persistentModelID.hashValue).\(slot)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
            }
        }
        if let m = measurement, !m.kinds.isEmpty {
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Measurement time")
            content.body = String(localized: "Take a minute to log your readings.")
            content.sound = .default
            var comps = DateComponents()
            comps.hour = m.hour
            comps.minute = m.minute
            try? await center.add(UNNotificationRequest(
                identifier: "measure.daily",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
        }
    }
}

enum SettingsStore {
    /// 演示模式内存覆盖:非 nil 时 targetRange(for:) 直接返回之,跳过 UserDefaults。
    /// App 重启自动 nil,零残留。
    static var demoRanges: [Reading.Kind: ClosedRange<Double>]?

    static func targetRange(for kind: Reading.Kind) -> ClosedRange<Double>? {
        if let demoRanges { return demoRanges[kind] }
        let lo = UserDefaults.standard.double(forKey: "target.\(kind.rawValue).lo")
        let hi = UserDefaults.standard.double(forKey: "target.\(kind.rawValue).hi")
        return hi > lo && hi > 0 ? lo...hi : nil
    }

    static func setTargetRange(_ range: ClosedRange<Double>?, for kind: Reading.Kind) {
        UserDefaults.standard.set(range?.lowerBound ?? 0, forKey: "target.\(kind.rawValue).lo")
        UserDefaults.standard.set(range?.upperBound ?? 0, forKey: "target.\(kind.rawValue).hi")
    }

    static var measurementReminder: MeasurementReminder? {
        get {
            UserDefaults.standard.data(forKey: "measurementReminder")
                .flatMap { try? JSONDecoder().decode(MeasurementReminder.self, from: $0) }
        }
        set {
            UserDefaults.standard.set(newValue.flatMap { try? JSONEncoder().encode($0) },
                                      forKey: "measurementReminder")
        }
    }
}

enum Disclaimer {
    // 合规红线: 纯记录工具的免责声明, en 源文案, zh-Hans 在 xcstrings
    static var text: String {
        String(localized: "Steady is a record-keeping tool, not a medical device. It does not diagnose, treat, or give medical advice. Target ranges shown are the ones you entered yourself. Always consult your doctor about your readings.")
    }
}
