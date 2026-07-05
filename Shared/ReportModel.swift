import Foundation

struct ReportModel {
    struct KindSection: Identifiable {
        let kind: Reading.Kind
        let readings: [Reading]
        let average: Double?
        let range: ClosedRange<Double>?
        let inRange: (Int, Int)?

        var id: String { kind.rawValue }
    }

    let interval: DateInterval
    let sections: [KindSection]
    let adherenceLine: String?
    let symptomLines: [String]

    init(readings: [Reading], symptoms: [SymptomEntry], meds: [Medication], medLogs: [MedLog],
         interval: DateInterval, targets: [Reading.Kind: ClosedRange<Double>]) {
        self.interval = interval
        let inWindow = readings.filter { interval.contains($0.date) }
        sections = Reading.Kind.allCases.compactMap { kind in
            let kindReadings = inWindow
                .filter { $0.kind == kind }
                .sorted { $0.date < $1.date }
            guard !kindReadings.isEmpty else { return nil }

            let values = kindReadings.map(\.value)
            let inRange = targets[kind].map { target in
                (Stats.inRangeCount(values, target: target), values.count)
            }
            return KindSection(
                kind: kind,
                readings: kindReadings,
                average: Stats.average(values),
                range: Stats.range(values),
                inRange: inRange)
        }

        let days = max(1, Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        let expected = meds
            .filter { !$0.archived }
            .map { $0.times.count * days }
            .reduce(0, +)
        let taken = medLogs.filter { interval.contains($0.date) && $0.taken }.count
        adherenceLine = Stats.adherence(taken: taken, expected: expected).map {
            "\(taken) of \(expected) scheduled doses logged (\($0.formatted(.percent.precision(.fractionLength(0)))))"
        }

        symptomLines = symptoms
            .filter { interval.contains($0.date) }
            .sorted { $0.date < $1.date }
            .map {
                "\($0.date.formatted(date: .abbreviated, time: .omitted)) - \($0.name) (\($0.severity)/3)"
                    + ($0.note.isEmpty ? "" : ": \($0.note)")
            }
    }

    static func csv(readings: [Reading]) -> String {
        let formatter = ISO8601DateFormatter()

        func escape(_ value: String) -> String {
            if value.contains(where: { ",\"\n\r".contains($0) }) {
                return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
            }
            return value
        }

        let rows = readings.sorted { $0.date < $1.date }.map { reading in
            [
                formatter.string(from: reading.date),
                reading.kind.rawValue,
                "\(reading.value)",
                reading.secondary.map { "\($0)" } ?? "",
                reading.mealtime.map { "\($0.rawValue)" } ?? "",
                escape(reading.note ?? ""),
            ].joined(separator: ",")
        }
        return (["date,kind,value,secondary,mealtime,note"] + rows).joined(separator: "\n")
    }
}
