import XCTest

/// Chinese screenshots via the app's `-seedDemo` in-memory demo data.
final class ScreenshotTests: XCTestCase {

    private func save(_ shot: XCUIScreenshot, _ name: String) {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? shot.pngRepresentation.write(to: dir.appendingPathComponent(name))
        let a = XCTAttachment(screenshot: shot); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    @MainActor
    func testCaptureScreenshots() {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_Hans", "-seedDemo"]
        app.launch()
        sleep(8)
        save(XCUIScreen.main.screenshot(), "steady-zh-1-timeline.png")

        // Trends = tab index 1, Meds = index 2 (language-agnostic).
        let tabs = app.tabBars.buttons
        if tabs.count > 1 { tabs.element(boundBy: 1).tap(); sleep(3) }
        save(XCUIScreen.main.screenshot(), "steady-zh-2-trends.png")
        if tabs.count > 2 { tabs.element(boundBy: 2).tap(); sleep(2) }
        save(XCUIScreen.main.screenshot(), "steady-zh-3-meds.png")
    }
}
