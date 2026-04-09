import XCTest
@testable import SlicerWorksApp

final class AppStatusTests: XCTestCase {
    func testIdleMessageIsExposed() {
        let status = AppStatus.idle(message: "Ready")

        XCTAssertEqual(status.message, "Ready")
        XCTAssertFalse(status.isWorking)
    }

    func testWorkingStatusReportsWorkingState() {
        let status = AppStatus.working(message: "Processing")

        XCTAssertEqual(status.message, "Processing")
        XCTAssertTrue(status.isWorking)
    }

    func testFailureStatusUsesLocalizedErrorDescription() {
        let status = AppStatus.failure(.missingSliceResult)

        XCTAssertEqual(status.message, "Slice the project before uploading")
        XCTAssertFalse(status.isWorking)
    }
}
