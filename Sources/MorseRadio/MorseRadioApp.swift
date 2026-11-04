import AppKit
import SwiftUI

@main
enum MorseRadioApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let radio = RadioManager()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var keyEventMonitor: Any?
    private var isWaitingForSpace = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if let button = statusItem.button {
            button.image = nil
            button.title = "· —"
            button.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            button.setAccessibilityLabel("Morse Radio, dot and dash")
            button.toolTip = "Morse Radio — 周波数 \(radio.frequency)"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 300, height: 250)
        popover.contentViewController = NSHostingController(rootView: RadioPopoverView(radio: radio))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(popoverDidClose),
            name: NSPopover.didCloseNotification,
            object: popover
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: NSApplication.willResignActiveNotification,
            object: nil
        )

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self, self.isWaitingForSpace, event.keyCode == 49 else { return event }
            if event.type == .keyDown {
                if !event.isARepeat { self.radio.beginLocalKey() }
            } else {
                self.radio.endLocalKey()
            }
            return nil
        }
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu(from: button)
        } else {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                isWaitingForSpace = true
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let frequency = NSMenuItem(title: "周波数: \(radio.frequency)", action: nil, keyEquivalent: "")
        frequency.isEnabled = false
        menu.addItem(frequency)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "周波数を設定…", action: #selector(openFrequencySettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items where item.action != nil {
            item.target = self
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.maxY), in: button)
    }

    @objc private func openFrequencySettings() {
        let alert = NSAlert()
        alert.messageText = "仮想周波数を設定"
        alert.informativeText = "同じ周波数の利用者同士が通信できます。例: 145.500"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        let field = NSTextField(string: radio.frequency)
        field.placeholderString = "例: 145.500"
        field.frame = NSRect(x: 0, y: 0, width: 240, height: 24)
        alert.accessoryView = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        guard radio.setFrequency(field.stringValue) else {
            let invalid = NSAlert()
            invalid.messageText = "周波数を確認してください"
            invalid.informativeText = "1〜24文字の英数字、ピリオド、ハイフン、アンダースコアを使えます。"
            invalid.runModal()
            return
        }
        statusItem.button?.toolTip = "Morse Radio — 周波数 \(radio.frequency)"
    }

    @objc private func popoverDidClose() {
        isWaitingForSpace = false
        radio.endLocalKey()
    }

    @objc private func appWillResignActive() {
        isWaitingForSpace = false
        radio.endLocalKey()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private struct RadioPopoverView: View {
    @ObservedObject var radio: RadioManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morse Radio").font(.headline)
                    Text("待機中 · 周波数 \(radio.frequency)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            MorseKeyCaptureView(radio: radio)
                .frame(height: 72)

            HStack(spacing: 6) {
                Circle()
                    .fill(radio.peerNames.isEmpty ? Color.secondary.opacity(0.45) : Color.green)
                    .frame(width: 7, height: 7)
                Text(radio.peerNames.isEmpty ? "Space 待機中 · 同じ周波数を検索中" : "接続中: \(radio.peerNames.count)人")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !radio.peerNames.isEmpty {
                Text(radio.peerNames.joined(separator: "、"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()
            HStack {
                Text("Space を短く押すと短点、長押しで長点")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(width: 300, height: 250)
    }
}
