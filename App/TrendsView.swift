import SwiftUI
import SwiftData
import Charts

enum TrendRange: String, CaseIterable, Identifiable {
    case week = "7D"
    case month = "30D"
    case quarter = "90D"

    var id: String { rawValue }
    var days: Int {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        }
    }
    var requiresPro: Bool { self != .week }
}

struct TrendsView: View {
    @Environment(HealthStore.self) private var health
    @Environment(ProStore.self) private var pro
    @Query private var meds: [Medication]
    @Query private var medLogs: [MedLog]
    @State private var kind: Reading.Kind = .bloodPressure
    @State private var range: TrendRange = .week
    @State private var showPaywall = false

    private var cutoff: Date {
        Calendar.current.date(byAdding: .day, value: -range.days, to: .now) ?? .now
    }

    private var data: [Reading] {
        health.readings
            .filter { $0.kind == kind && $0.date >= cutoff }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Type", selection: $kind) {
                    ForEach(Reading.Kind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }

                Picker("Range", selection: rangeBinding) {
                    ForEach(TrendRange.allCases) { range in
                        Text(rangeTitle(range)).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                Section {
                    chart
                    factRows
                }

                Section("Medication") {
                    adherenceRow
                }
            }
            .navigationTitle("Trends")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var rangeBinding: Binding<TrendRange> {
        Binding(
            get: { range },
            set: { newValue in
                if newValue.requiresPro && !pro.isPro {
                    showPaywall = true
                } else {
                    range = newValue
                }
            })
    }

    private func rangeTitle(_ range: TrendRange) -> String {
        range.requiresPro && !pro.isPro ? "\(range.rawValue) Pro" : range.rawValue
    }

    private var chart: some View {
        Chart(data) { reading in
            LineMark(
                x: .value("Date", reading.date),
                y: .value(kind.displayName, reading.value))
                .foregroundStyle(Theme.sun)
            PointMark(
                x: .value("Date", reading.date),
                y: .value(kind.displayName, reading.value))
                .foregroundStyle(Theme.sun)

            if let secondary = reading.secondary {
                LineMark(
                    x: .value("Date", reading.date),
                    y: .value("Diastolic", secondary))
                    .foregroundStyle(Theme.pebble)
            }
        }
        .frame(height: 220)
        .chartYScale(domain: .automatic(includesZero: false))
        .overlay {
            if data.isEmpty {
                ContentUnavailableView("No data in range", systemImage: "chart.xyaxis.line")
            }
        }
    }

    @ViewBuilder
    private var factRows: some View {
        let values = data.map(\.value)
        if let average = Stats.average(values) {
            LabeledContent(
                "Average",
                value: "\(average.formatted(.number.precision(.fractionLength(0...1)))) \(health.unitLabel(for: kind))")
        }
        if let range = Stats.range(values) {
            LabeledContent(
                "Range",
                value: "\(range.lowerBound.formatted(.number.precision(.fractionLength(0...1))))-\(range.upperBound.formatted(.number.precision(.fractionLength(0...1))))")
        }
        if let target = SettingsStore.targetRange(for: kind), !values.isEmpty {
            LabeledContent(
                "Readings in your range",
                value: "\(Stats.inRangeCount(values, target: target)) of \(values.count)")
        }
    }

    @ViewBuilder
    private var adherenceRow: some View {
        let logs = medLogs.filter { $0.date >= cutoff && $0.taken }
        let expected = meds
            .filter { !$0.archived }
            .map { $0.times.count * range.days }
            .reduce(0, +)
        if let adherence = Stats.adherence(taken: logs.count, expected: expected) {
            LabeledContent(
                "Doses logged",
                value: "\(logs.count) of \(expected) (\(adherence.formatted(.percent.precision(.fractionLength(0)))))")
        } else {
            Text("No medications set up.")
                .foregroundStyle(Theme.secondaryText)
        }
    }
}
