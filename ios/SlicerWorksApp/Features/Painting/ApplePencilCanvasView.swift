import SwiftUI
import UIKit

struct ApplePencilCanvasView: UIViewRepresentable {
    var onHoverChanged: (CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void
    var onStrokeBegan: (CGPoint, CGFloat, CGFloat, CGFloat) -> Void
    var onStrokeMoved: (CGPoint, CGFloat, CGFloat, CGFloat) -> Void
    var onStrokeEnded: () -> Void
    var onTap: (CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void
    var onSqueeze: (CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onTap: onTap,
            onSqueeze: onSqueeze
        )
    }

    func makeUIView(context: Context) -> PencilCanvasUIView {
        let view = PencilCanvasUIView()
        view.onHoverChanged = onHoverChanged
        view.onStrokeBegan = onStrokeBegan
        view.onStrokeMoved = onStrokeMoved
        view.onStrokeEnded = onStrokeEnded
        view.installPencilInteraction(delegate: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: PencilCanvasUIView, context: Context) {
        uiView.onHoverChanged = onHoverChanged
        uiView.onStrokeBegan = onStrokeBegan
        uiView.onStrokeMoved = onStrokeMoved
        uiView.onStrokeEnded = onStrokeEnded
        context.coordinator.onTap = onTap
        context.coordinator.onSqueeze = onSqueeze
    }

    final class Coordinator: NSObject, UIPencilInteractionDelegate {
        var onTap: (CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void
        var onSqueeze: (CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void

        init(
            onTap: @escaping (CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void,
            onSqueeze: @escaping (CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void
        ) {
            self.onTap = onTap
            self.onSqueeze = onSqueeze
        }

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            onTap(nil, .zero, .zero, .zero, .zero)
        }

        @available(iOS 17.5, *)
        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
            let hoverPose = tap.hoverPose
            onTap(
                hoverPose?.location,
                hoverPose?.azimuthAngle ?? .zero,
                hoverPose?.altitudeAngle ?? .zero,
                hoverPose?.zOffset ?? .zero,
                hoverPose?.rollAngle ?? .zero
            )
        }

        @available(iOS 17.5, *)
        func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
            let hoverPose = squeeze.hoverPose
            onSqueeze(
                hoverPose?.location,
                hoverPose?.azimuthAngle ?? .zero,
                hoverPose?.altitudeAngle ?? .zero,
                hoverPose?.zOffset ?? .zero,
                hoverPose?.rollAngle ?? .zero
            )
        }
    }
}

final class PencilCanvasUIView: UIView {
    var onHoverChanged: ((CGPoint?, CGFloat, CGFloat, CGFloat, CGFloat) -> Void)?
    var onStrokeBegan: ((CGPoint, CGFloat, CGFloat, CGFloat) -> Void)?
    var onStrokeMoved: ((CGPoint, CGFloat, CGFloat, CGFloat) -> Void)?
    var onStrokeEnded: (() -> Void)?

    private lazy var hoverGestureRecognizer: UIHoverGestureRecognizer = {
        let recognizer = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        addGestureRecognizer(hoverGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func installPencilInteraction(delegate: UIPencilInteractionDelegate) {
        if #available(iOS 17.5, *) {
            let interaction = UIPencilInteraction(delegate: delegate)
            addInteraction(interaction)
        } else {
            let interaction = UIPencilInteraction()
            interaction.delegate = delegate
            addInteraction(interaction)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch.type == .pencil else {
            super.touchesBegan(touches, with: event)
            return
        }

        onStrokeBegan?(
            touch.preciseLocation(in: self),
            touch.force,
            touch.azimuthAngle(in: self),
            touch.rollAngle
        )
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch.type == .pencil else {
            super.touchesMoved(touches, with: event)
            return
        }

        onStrokeMoved?(
            touch.preciseLocation(in: self),
            touch.force,
            touch.azimuthAngle(in: self),
            touch.rollAngle
        )
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch.type == .pencil else {
            super.touchesEnded(touches, with: event)
            return
        }

        onStrokeMoved?(
            touch.preciseLocation(in: self),
            touch.force,
            touch.azimuthAngle(in: self),
            touch.rollAngle
        )
        onStrokeEnded?()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        onStrokeEnded?()
        super.touchesCancelled(touches, with: event)
    }

    @objc
    private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            onHoverChanged?(
                recognizer.location(in: self),
                recognizer.azimuthAngle(in: self),
                recognizer.altitudeAngle,
                recognizer.zOffset,
                recognizer.rollAngle
            )
        default:
            onHoverChanged?(nil, .zero, .zero, .zero, .zero)
        }
    }
}
