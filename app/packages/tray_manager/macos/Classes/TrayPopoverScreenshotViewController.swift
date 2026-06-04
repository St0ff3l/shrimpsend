import AppKit

/// Popover content: entry points for full-screen and region capture.
final class TrayPopoverScreenshotViewController: NSViewController {
    var onFullScreen: (() -> Void)?
    var onRegion: (() -> Void)?

    override func loadView() {
        let size = NSSize(width: 360, height: 200)
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 1).cgColor
        view = root

        let title = NSTextField(labelWithString: "截图")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = NSColor.white.withAlphaComponent(0.9)

        let fullBtn = makeActionButton(title: "全屏截图", action: #selector(didTapFull))
        let regionBtn = makeActionButton(title: "区域截图", action: #selector(didTapRegion))

        title.translatesAutoresizingMaskIntoConstraints = false
        fullBtn.translatesAutoresizingMaskIntoConstraints = false
        regionBtn.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(title)
        root.addSubview(fullBtn)
        root.addSubview(regionBtn)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            title.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),

            fullBtn.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            fullBtn.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            fullBtn.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            fullBtn.heightAnchor.constraint(equalToConstant: 32),

            regionBtn.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            regionBtn.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            regionBtn.topAnchor.constraint(equalTo: fullBtn.bottomAnchor, constant: 10),
            regionBtn.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func makeActionButton(title: String, action: Selector) -> NSButton {
        let b = NSButton(frame: .zero)
        b.title = title
        b.target = self
        b.action = action
        b.bezelStyle = .rounded
        if #available(macOS 11.0, *) {
            b.controlSize = .large
        } else {
            b.controlSize = .regular
        }
        b.font = NSFont.systemFont(ofSize: 13)
        if #available(macOS 11.0, *) {
            b.contentTintColor = .white
        }
        return b
    }

    @objc private func didTapFull() {
        onFullScreen?()
    }

    @objc private func didTapRegion() {
        onRegion?()
    }
}
