import Foundation

enum Stats {
    static func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
    static func range(_ values: [Double]) -> ClosedRange<Double>? {
        guard let lo = values.min(), let hi = values.max() else { return nil }
        return lo...hi
    }
    static func inRangeCount(_ values: [Double], target: ClosedRange<Double>) -> Int {
        values.filter(target.contains).count
    }
    static func adherence(taken: Int, expected: Int) -> Double? {
        expected > 0 ? Double(taken) / Double(expected) : nil
    }
}
