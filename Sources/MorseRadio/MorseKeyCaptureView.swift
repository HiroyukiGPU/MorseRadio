import AppKit
import SwiftUI

struct MorseKeyCaptureView: NSViewRepresentable {
    @ObservedObject var radio: RadioManager

    func makeNSView(context: Context) -> MorseKeyView {
        let view = MorseKeyView(frame: .zero)
        view.onPress = { radio.beginLocalKey() }
        view.onRelease = { radio.endLocalKey() }
        view.isTransmitting = radio.isSending
        return view
    }

    func updateNSView(_ nsView: MorseKeyView, context: Context) {
        nsView.isTransmitting = radio.isSending
        nsView.needsDisplay = true
    }
}

final class MorseKeyView: NSView {
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var isTransmitting = false

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            window.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 49 else {
            super.keyDown(with: event)
            return
        }
        guard !event.isARepeat else { return }
        onPress?()
    }

    override func keyUp(with event: NSEvent) {
        guard event.keyCode == 49 else {
            super.keyUp(with: event)
            return
        }
        onRelease?()
    }

    override func draw(_ dirtyRect: NSRect) {
        let panel = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: panel, xRadius: 12, yRadius: 12)
        NSColor.controlBackgroundColor.setFill()
        path.fill()
        (isTransmitting ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.lineWidth = isTransmitting ? 2 : 1
        path.stroke()

        let label = isTransmitting ? "送信中… Space を離して終了" : "Space を押して送信"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: isTransmitting ? NSColor.controlAccentColor : NSColor.labelColor
        ]
        let size = (label as NSString).size(withAttributes: attributes)
        (label as NSString).draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}
