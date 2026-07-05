import SwiftUI
import SwiftData

struct ReportView: View {
    @Environment(HealthStore.self) private var health
    @Environment(ProStore.self) private var pro
    @Query private var symptoms: [SymptomEntry]
    @Query private var meds: [Medication]
    @Query private var medLogs: [MedLog]
    @State private var start = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    @State private var end = Date.now
    @State private var pdfURL: URL?
    @State private var showPaywall = false

    var body: some View {
        Form {
            DatePicker("From", selection: $start, displayedComponents: .date)
            DatePicker("To", selection: $end, displayedComponents: .date)
            Button("Generate PDF", systemImage: "doc.richtext") {
                if pro.isPro {
                    render()
                } else {
                    showPaywall = true
                }
            }
            if let pdfURL {
                ShareLink(item: pdfURL) {
                    Label("Share report", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("Doctor report")
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }

    private var model: ReportModel {
        let startDay = Calendar.current.startOfDay(for: min(start, end))
        let endDay = Calendar.current.startOfDay(for: max(start, end))
        let exclusiveEnd = Calendar.current.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        return ReportModel(
            readings: health.readings,
            symptoms: symptoms,
            meds: meds,
            medLogs: medLogs,
            interval: DateInterval(start: startDay, end: exclusiveEnd),
            targets: Dictionary(uniqueKeysWithValues: Reading.Kind.allCases.compactMap { kind in
                SettingsStore.targetRange(for: kind).map { (kind, $0) }
            }))
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: ReportDocument(
            model: model,
            unitLabel: { health.unitLabel(for: $0) }))
        let url = URL.temporaryDirectory.appending(path: "Steady-report.pdf")
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: CGSize(width: 612, height: max(792, size.height)))
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        pdfURL = url
    }
}

struct ReportDocument: View {
    let model: ReportModel
    let unitLabel: (Reading.Kind) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Steady - Health record")
                .font(.title.bold())
            Text(dateRange)
                .foregroundStyle(.secondary)

            ForEach(model.sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.kind.displayName)
                        .font(.headline)
                    if let average = section.average {
                        Text(summary(for: section, average: average))
                            .font(.subheadline)
                    }
                    ForEach(section.readings) { reading in
                        Text(readingLine(reading))
                            .font(.caption.monospaced())
                    }
                }
            }

            if let adherence = model.adherenceLine {
                Text("Medication")
                    .font(.headline)
                Text(adherence)
                    .font(.subheadline)
            }

            if !model.symptomLines.isEmpty {
                Text("Symptoms")
                    .font(.headline)
                ForEach(model.symptomLines, id: \.self) { line in
                    Text(line)
                        .font(.caption)
                }
            }

            Divider()
            Text(Disclaimer.text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(48)
        .frame(width: 612)
        .background(.white)
        .foregroundStyle(.black)
    }

    private var dateRange: String {
        let inclusiveEnd = Calendar.current.date(byAdding: .second, value: -1, to: model.interval.end) ?? model.interval.end
        return "\(model.interval.start.formatted(date: .abbreviated, time: .omitted)) - \(inclusiveEnd.formatted(date: .abbreviated, time: .omitted))"
    }

    private func summary(for section: ReportModel.KindSection, average: Double) -> String {
        var parts = [
            "Average \(average.formatted(.number.precision(.fractionLength(0...1)))) \(unitLabel(section.kind))",
        ]
        if let range = section.range {
            parts.append("Range \(range.lowerBound.formatted(.number.precision(.fractionLength(0...1))))-\(range.upperBound.formatted(.number.precision(.fractionLength(0...1))))")
        }
        if let inRange = section.inRange {
            parts.append("\(inRange.0) of \(inRange.1) in patient-set range")
        }
        return parts.joined(separator: " | ")
    }

    private func readingLine(_ reading: Reading) -> String {
        reading.date.formatted(date: .numeric, time: .shortened)
            + "  \(reading.display)"
            + (reading.mealtime.map { "  (\($0.label))" } ?? "")
            + (reading.note.map { "  - \($0)" } ?? "")
    }
}
