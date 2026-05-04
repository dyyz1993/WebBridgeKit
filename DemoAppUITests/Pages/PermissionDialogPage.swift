import XCTest

/// Page Object for handling system permission dialogs
class PermissionDialogPage: BasePage {

    // MARK: - System Dialog Elements

    /// System alert dialog for permission requests
    var systemAlert: XCUIElement {
        return app.alerts.firstMatch
    }

    /// "OK" or "Allow" button in permission dialog
    var allowButton: XCUIElement {
        // Try multiple possible button labels
        return app.buttons["OK"].exists ? app.buttons["OK"] :
               app.buttons["Allow"].exists ? app.buttons["Allow"] :
               app.buttons["Allow Access"].exists ? app.buttons["Allow Access"] :
               app.buttons["允许"].exists ? app.buttons["允许"] :
               app.buttons["好"].exists ? app.buttons["好"] :
               app.buttons["Use While Using App"].exists ? app.buttons["Use While Using App"] :
               app.buttons["Allow While Using App"].exists ? app.buttons["Allow While Using App"] :
               app.buttons.element(boundBy: 1) // Usually the second button is Allow
    }

    /// "Don't Allow" button in permission dialog
    var denyButton: XCUIElement {
        return app.buttons["Don't Allow"].exists ? app.buttons["Don't Allow"] :
               app.buttons["不允许"].exists ? app.buttons["不允许"] :
               app.buttons.element(boundBy: 0) // Usually the first button is Deny
    }

    // MARK: - Camera Picker Elements

    /// Camera picker view controller
    var cameraPicker: XCUIElement {
        return app.otherElements["UIImagePickerController"]
    }

    /// Camera capture button
    var cameraCaptureButton: XCUIElement {
        return app.buttons["Capture"]
    }

    /// Photo library button in camera picker
    var photoLibraryButton: XCUIElement {
        return app.buttons["Photo Library"]
    }

    /// Cancel button in camera picker
    var cameraCancelButton: XCUIElement {
        return app.buttons["Cancel"]
    }

    // MARK: - Verification Methods

    /// Verify that a system permission dialog is displayed
    func verifyPermissionDialogShown() -> Bool {
        return waitForElementToAppear(systemAlert, timeout: 5)
    }

    /// Verify that camera picker is displayed
    func verifyCameraPickerShown() -> Bool {
        return waitForElementToAppear(cameraPicker, timeout: 5)
    }

    // MARK: - Action Methods

    /// Tap the "Allow" button on permission dialog
    func tapAllow() {
        XCTAssertTrue(verifyPermissionDialogShown(), "Permission dialog not shown")
        tapElement(allowButton)
    }

    /// Tap the "Don't Allow" button on permission dialog
    func tapDeny() {
        XCTAssertTrue(verifyPermissionDialogShown(), "Permission dialog not shown")
        tapElement(denyButton)
    }

    /// Wait for and handle permission dialog
    /// - Parameter allow: true to tap Allow, false to tap Deny
    func handlePermissionDialog(allow: Bool) -> Bool {
        guard verifyPermissionDialogShown() else {
            return false
        }

        if allow {
            tapAllow()
        } else {
            tapDeny()
        }

        return waitForElementToDisappear(systemAlert, timeout: 3)
    }

    /// Take photo in camera picker (if camera is available)
    func takePhoto() {
        XCTAssertTrue(verifyCameraPickerShown(), "Camera picker not shown")

        // Try to find and tap the capture button
        if cameraCaptureButton.exists {
            tapElement(cameraCaptureButton)
        }

        // Wait a moment for the photo to be captured
        Thread.sleep(forTimeInterval: 1.0)

        // The camera should dismiss automatically after capture
        // or we may need to tap "Use Photo"
        let usePhotoButton = app.buttons["Use Photo"]
        if usePhotoButton.exists {
            tapElement(usePhotoButton)
        }
    }

    /// Cancel camera picker
    func cancelCamera() {
        if cameraCancelButton.exists {
            tapElement(cameraCancelButton)
        }
    }

    /// Check if permission dialog exists without waiting
    func isPermissionDialogPresent() -> Bool {
        return systemAlert.exists
    }

    /// Get the title/text of the permission dialog
    func getPermissionDialogTitle() -> String? {
        if systemAlert.exists {
            return systemAlert.label
        }
        return nil
    }

    /// Get the message of the permission dialog
    func getPermissionDialogMessage() -> String? {
        if systemAlert.exists {
            return systemAlert.staticTexts.element(boundBy: 1).label
        }
        return nil
    }

    // MARK: - Complex Workflows

    /// Handle permission with retry logic
    /// - Parameters:
    ///   - allow: true to allow, false to deny
    ///   - maxRetries: maximum number of retry attempts
    /// - Returns: true if handled successfully, false otherwise
    func handlePermissionDialogWithRetry(allow: Bool, maxRetries: Int = 3) -> Bool {
        for attempt in 1...maxRetries {
            if isPermissionDialogPresent() {
                let success = handlePermissionDialog(allow: allow)
                if success {
                    return true
                }
            }
            Thread.sleep(forTimeInterval: TimeInterval(attempt) * 0.5)
        }
        return false
    }

    /// Dismiss any visible system alert
    func dismissAnyAlert() {
        if systemAlert.exists {
            // Try to find a dismiss button
            let dismissButtons = ["OK", "Cancel", "Dismiss", "关闭", "取消"]
            for buttonTitle in dismissButtons {
                let button = app.buttons[buttonTitle]
                if button.exists {
                    button.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                    return
                }
            }

            // If no standard button found, try tapping anywhere to dismiss
            app.tap()
        }
    }
}
