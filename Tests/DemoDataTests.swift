import XCTest
import SwiftData
@testable import Steady

final class DemoDataTests: XCTestCase {
    override func tearDown() {
        // static 内存覆盖不跨测试残留
        SettingsStore.demoRanges = nil
    }

    @MainActor
    func testSeedFillsAllSurfaces() throws {
        let container = SteadyModels.testContainer()
        let ctx = container.mainContext
        let health = HealthStore()

        DemoData.seed(into: health, ctx: ctx)

        // 测量覆盖全部 5 类
        let kinds = Set(health.readings.map(\.kind))
        XCTAssertEqual(kinds, Set(Reading.Kind.allCases))

        // 每类足够画图(≥ 20 点)
        for kind in Reading.Kind.allCases {
            XCTAssertGreaterThanOrEqual(
                health.readings.filter { $0.kind == kind }.count, 20)
        }

        // 覆盖到 90 天窗口(存在 ≥ 89 天前的点)
        let cal = Calendar.current
        let ninetyAgo = cal.date(byAdding: .day, value: -89, to: .now)!
        XCTAssertTrue(health.readings.contains { $0.date <= ninetyAgo })

        // 用药 2 个 + 今日打卡
        let meds = try ctx.fetch(FetchDescriptor<Medication>())
        XCTAssertEqual(meds.count, 2)
        let logs = try ctx.fetch(FetchDescriptor<MedLog>())
        XCTAssertFalse(logs.isEmpty)
        XCTAssertTrue(logs.allSatisfy { cal.isDateInToday($0.date) })

        // 症状 ≥ 3 条
        let symptoms = try ctx.fetch(FetchDescriptor<SymptomEntry>())
        XCTAssertGreaterThanOrEqual(symptoms.count, 3)

        // 目标范围走内存覆盖(非 nil)
        XCTAssertNotNil(SettingsStore.targetRange(for: .bloodPressure))
        XCTAssertNotNil(SettingsStore.targetRange(for: .glucose))
    }
}
