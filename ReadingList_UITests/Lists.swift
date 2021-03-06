import Foundation
import XCTest

class Lists: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        let app = ReadingListApplication()
        app.launchArguments.append("--UITests_PopulateData")
        app.launchArguments.append("--UITests_DeleteLists")
        app.launch()
        sleep(4)
    }

    override func tearDown() {
        super.tearDown()
    }

    func testFirstListPresentsAlertAndSecondListPresentsModal() {
        let app = ReadingListApplication()
        app.tables.cells.element(boundBy: 0).tap()
        app.scrollViews.otherElements.buttons["Add to List"].tap()

        XCTAssertEqual(app.alerts.count, 1, "Alert should appear when adding first list")
        let addNewListAlert = app.alerts.firstMatch
        let enterListNameTextField = addNewListAlert.collectionViews.textFields.firstMatch
        enterListNameTextField.typeText("A List")
        addNewListAlert.buttons["OK"].tap()

        app.clickTab(.organise)
        XCTAssertEqual(app.tables.cells.count, 1, "Should be one list in organise tab")

        app.clickTab(.toRead)
        app.scrollViews.otherElements.buttons["Add to List"].tap()

        let modalTable = app.tables.element(boundBy: 0)
        XCTAssertEqual(modalTable.cells.count, 2, "Should be 2 table rows in modal list selector")
        XCTAssertEqual(false, modalTable.cells.element(boundBy: 0).isEnabled, "Add to List A should not be hittable")
        XCTAssertEqual(true, modalTable.cells.element(boundBy: 1).isEnabled, "Add to List A should not be hittable")

        modalTable.cells.element(boundBy: 1).tap()
        XCTAssertEqual(app.alerts.count, 1, "Alert should appear when adding new list")
        let addList2Alert = app.alerts.firstMatch
        let enterList2NameTextField = addNewListAlert.collectionViews.textFields.firstMatch
        enterList2NameTextField.typeText("B List")
        addList2Alert.buttons["OK"].tap()

    }
}
