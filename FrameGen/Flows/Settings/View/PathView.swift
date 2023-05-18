//
//  PathView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

protocol PathViewProtocol: AnyObject {
    func didTapChooseFolder()
}

final class PathView: NSView {
    
    // MARK: - Properties
    
    enum PathStateType {
        case `default`
        case custom
        
        var isEditable: Bool {
            switch self {
            case .default: return false
            case .custom: return true
            }
        }
        
        var isHiddenFolderButton: Bool {
            switch self {
            case .default: return true
            case .custom: return false
            }
        }
    }
    
    weak var delegate: PathViewProtocol?
    
    private var state: PathStateType = .default {
        didSet {
            updateContent()
        }
    }
    
    private let textField: NSTextField = {
        let textField = NSTextField()
        textField.isEditable = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        return textField
    }()
    private lazy var folderButton: NSButton = {
        let image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        let button = NSButton(image: image!,
                              target: self,
                              action: #selector(didTapFolder(_: )))
        button.contentTintColor = .systemBlue
        button.imageScaling = .scaleNone
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.isBordered = false
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }()
    
    // MARK: - Initial methods
    
    required init() {
        super.init(frame: .zero)
        
        configureView()
        configureLayout()
        updateContent()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public methods
    
    func updateState(_ newState: PathStateType) {
        state = newState
    }
    
    // MARK: - Private methods
    
    private func configureView() {
        addSubview(textField)
        addSubview(folderButton)
    }
    
    private func configureLayout() {
        let constraints = [textField.topAnchor.constraint(equalTo: topAnchor),
                           textField.leadingAnchor.constraint(equalTo: leadingAnchor),
                           bottomAnchor.constraint(equalTo: textField.bottomAnchor),
                           folderButton.topAnchor.constraint(equalTo: topAnchor),
                           folderButton.leadingAnchor.constraint(equalTo: textField.trailingAnchor),
                           folderButton.widthAnchor.constraint(equalToConstant: 40),
                           trailingAnchor.constraint(equalTo: folderButton.trailingAnchor),
                           bottomAnchor.constraint(equalTo: folderButton.bottomAnchor)]
        NSLayoutConstraint.activate(constraints)
    }
    
    private func updateContent() {
        textField.isEditable = state.isEditable
        folderButton.isHidden = state.isHiddenFolderButton
        textField.stringValue = configurePath()
    }
    
    private func configurePath() -> String {
        let manager = SettingsManager.shared
        let defaultFolder = manager.getDefaultFolder()
        let folder = manager.getFolder()
        
        switch state {
        case .default:
            return getDefaultPath()
        case .custom:
            if folder.path != defaultFolder.path {
                return folder.path
            } else {
                return getDefaultPath()
            }
        }
    }
    
    private func getDefaultPath() -> String {
        let manager = SettingsManager.shared
        let defaultFolder = manager.getDefaultFolder()
        
        return "${PROJECT_DIR}/\(defaultFolder.path)/"
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapFolder(_ sender: NSButton) {
        delegate?.didTapChooseFolder()
    }
    
}
