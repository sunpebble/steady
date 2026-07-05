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
    static var measurementReminder: MeasurementReminder? { nil }
}
