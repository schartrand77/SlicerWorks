import XCTest
@testable import SlicerWorks

final class WorkspaceCameraTests: XCTestCase {
    func testApplyDragOrbitsUsingViewportSize() {
        let start = WorkspaceCamera()
        var camera = start
        camera.interactionMode = .orbit

        camera.applyDrag(
            from: start,
            translation: CGSize(width: 100, height: 50),
            in: CGSize(width: 400, height: 200)
        )

        XCTAssertEqual(camera.yaw, 19, accuracy: 0.001)
        XCTAssertEqual(camera.pitch, 28, accuracy: 0.001)
        XCTAssertEqual(camera.pan.width, 0, accuracy: 0.001)
        XCTAssertEqual(camera.pan.height, 0, accuracy: 0.001)
    }

    func testApplyDragPansWithoutChangingRotation() {
        let start = WorkspaceCamera()
        var camera = start
        camera.interactionMode = .pan

        camera.applyDrag(
            from: start,
            translation: CGSize(width: 42, height: -18),
            in: CGSize(width: 400, height: 200)
        )

        XCTAssertEqual(camera.pan.width, 42, accuracy: 0.001)
        XCTAssertEqual(camera.pan.height, -18, accuracy: 0.001)
        XCTAssertEqual(camera.yaw, start.yaw, accuracy: 0.001)
        XCTAssertEqual(camera.pitch, start.pitch, accuracy: 0.001)
    }

    func testApplyMagnificationClampsZoomRange() {
        var camera = WorkspaceCamera()

        camera.applyMagnification(from: 1, magnification: 0.1)
        XCTAssertEqual(camera.zoom, WorkspaceCamera.minimumZoom, accuracy: 0.001)

        camera.applyMagnification(from: 1.5, magnification: 5)
        XCTAssertEqual(camera.zoom, WorkspaceCamera.maximumZoom, accuracy: 0.001)
    }
}
