import Foundation
import SwiftData

@Model
final class Medication {
    var name: String = ""
    var dosage: String = ""
    var times: [Int] = []
    var archived: Bool = false
    var createdAt: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \MedLog.medication)
    var logs: [MedLog]? = nil

    init(name: String = "", dosage: String = "", times: [Int] = []) {
        self.name = name; self.dosage = dosage; self.times = times
    }
}

@Model
final class MedLog {
    var date: Date = Date()
    var slot: Int = 0
    var taken: Bool = true
    var medication: Medication? = nil

    init(date: Date = .now, slot: Int = 0, taken: Bool = true, medication: Medication? = nil) {
        self.date = date; self.slot = slot; self.taken = taken; self.medication = medication
    }
}

@Model
final class SymptomEntry {
    var name: String = ""
    var severity: Int = 1
    var date: Date = Date()
    var note: String = ""

    init(name: String = "", severity: Int = 1, date: Date = .now, note: String = "") {
        self.name = name; self.severity = severity; self.date = date; self.note = note
    }
}

enum SteadyModels {
    static let schema = Schema([Medication.self, MedLog.self, SymptomEntry.self])

    static func container() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.sunpebble.steady"))
        return try ModelContainer(for: schema, configurations: config)
    }

    static func testContainer() -> ModelContainer {
        return try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    }
}
