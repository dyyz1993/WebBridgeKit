import XCTest

/// Launches the app with the fixtures the three external-precondition
/// favorites tests historically received from an out-of-band `simctl push`.
enum FavoriteTestFixtures {
    static func launch(app: XCUIApplication) {
        app.launchArguments = [
            "--UITesting",
            "-UITesting",
            "--register-favorite-fixtures"
        ]
        app.launchEnvironment = [
            "AppleLanguages": "(zh-Hans)",
            "AppleLocale": "zh_CN"
        ]
        app.launch()
    }
}
