//
//  CopyButton.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Copies a value to the pasteboard and briefly confirms it with a checkmark.
final class CopyButton: NSButton {

    // MARK: - Properties

    private let value: () -> String
    private let defaultTitle: String
    private var resetTask: Task<Void, Never>?

    // MARK: - Initial methods

    init(title: String = String(localized: "Copy"), value: @escaping () -> String) {
        self.value = value
        defaultTitle = title
        super.init(frame: .zero)

        self.title = title
        bezelStyle = .push
        image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        imagePosition = .imageLeading
        target = self
        action = #selector(copyValue(_:))
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Actions

    @objc
    private func copyValue(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value(), forType: .string)

        title = String(localized: "Copied")
        image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        NSAccessibility.post(element: self, notification: .announcementRequested,
                             userInfo: [.announcement: String(localized: "Copied to the clipboard")])
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled else { return }

            title = defaultTitle
            image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
        }
    }

}
