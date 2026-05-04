import XCTest

final class LocationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }
    
    override func tearDownWithError() throws {
        // Take final screenshot
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Final_State"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    func testLocationFeature() throws {
        // Take initial screenshot
        let initialScreenshot = XCUIScreen.main.screenshot()
        let initialAttachment = XCTAttachment(screenshot: initialScreenshot)
        initialAttachment.name = "01_Initial_Launch"
        initialAttachment.lifetime = .keepAlways
        add(initialAttachment)
        
        // Wait for app to fully load
        let webViewsQuery = app.webViews
        XCTAssertTrue(webViewsQuery.firstMatch.waitForExistence(timeout: 10), "Web view should appear")
        
        // Look for URL input or navigation elements
        let textFields = app.textFields
        let urlField = textFields.element(boundBy: 0)
        
        if urlField.exists {
            urlField.tap()
            urlField.typeText("http://localhost:8080/js_bridge_test.html")
            
            // Take screenshot after entering URL
            let urlEnteredScreenshot = XCUIScreen.main.screenshot()
            let urlAttachment = XCTAttachment(screenshot: urlEnteredScreenshot)
            urlAttachment.name = "02_URL_Entered"
            urlAttachment.lifetime = .keepAlways
            add(urlAttachment)
            
            // Press Enter to navigate
            app.keyboards.buttons["Go"].tap()
        }
        
        // Wait for page to load
        sleep(5)
        
        // Take screenshot after page load
        let pageLoadScreenshot = XCUIScreen.main.screenshot()
        let pageAttachment = XCTAttachment(screenshot: pageLoadScreenshot)
        pageAttachment.name = "03_Page_Loaded"
        pageAttachment.lifetime = .keepAlways
        add(pageAttachment)
        
        // Look for location button in web view
        let getLocationButton = app.buttons["Get Location"]
        if getLocationButton.exists {
            getLocationButton.tap()
            
            // Wait for location permission dialog
            sleep(3)
            
            // Handle permission dialog if it appears
            let allowButton = app.buttons["Allow"]
            if allowButton.exists {
                allowButton.tap()
            }
            
            // Wait for location result
            sleep(5)
            
            // Take final screenshot showing location result
            let resultScreenshot = XCUIScreen.main.screenshot()
            let resultAttachment = XCTAttachment(screenshot: resultScreenshot)
            resultAttachment.name = "04_Location_Result"
            resultAttachment.lifetime = .keepAlways
            add(resultAttachment)
        }
    }
}
