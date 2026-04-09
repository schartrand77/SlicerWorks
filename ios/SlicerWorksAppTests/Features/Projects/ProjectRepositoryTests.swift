import XCTest
@testable import SlicerWorks

final class ProjectRepositoryTests: XCTestCase {
    func testInMemoryRepositoryRoundTripsDocument() throws {
        let repository = InMemoryProjectRepository()
        let document = SliceProjectDocument.example

        try repository.saveProject(document)

        XCTAssertEqual(try repository.loadLastProject(), document)
    }

    func testUserDefaultsRepositoryRoundTripsDocument() throws {
        let suiteName = "ProjectRepositoryTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

        let repository = UserDefaultsProjectRepository(defaults: defaults)
        let document = SliceProjectDocument.example

        try repository.saveProject(document)

        XCTAssertEqual(try repository.loadLastProject(), document)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
