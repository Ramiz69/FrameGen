//
//  ContentView.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

protocol ContentViewProtocol: AnyObject {
    
    func fileSelected(_ path: String)
    func didTapSettings()
    
}

final class ContentView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: ContentViewProtocol?
    
    private enum Constants {
        static let offset: CGFloat = 32
        static let settingsButtonSize = NSSize(width: 25, height: 25)
    }
    
    private let projectImageView: NSImageView = {
        guard let image = NSImage(named: "project") else {
            fatalError("The project image not found")
        }
        
        let imageView = NSImageView(image: image)
        imageView.contentTintColor = NSColor.labelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        return imageView
    }()
    private lazy var addFileButton: NSButton = {
        let button = NSButton(title: "Add a project directory",
                              target: self,
                              action: #selector(didTapAddFileButton(_ :)))
        button.bezelColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }()
    private(set) lazy var settingsButton: NSButton = {
        let image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        let button = NSButton(image: image!,
                              target: self,
                              action: #selector(didTapSettings(_ :)))
        button.imageScaling = .scaleProportionallyUpOrDown
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }()
    private let openPanel: NSOpenPanel = {
        let panel = NSOpenPanel()
        panel.worksWhenModal = true
        panel.title = "Choose a project directory"
        panel.showsResizeIndicator = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        return panel
    }()
    private let dropView = DropView()
    
    // MARK: - Initial methods
    
    required init() {
        super.init(frame: .zero)
        
        configureView()
        configureConstraints()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Private methods
    
    private func configureView() {
        openPanel.delegate = self
        dropView.delegate = self
        dropView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dropView)
        addSubview(addFileButton)
        addSubview(projectImageView, positioned: .below, relativeTo: dropView)
        addSubview(settingsButton)
    }
    
    private func configureConstraints() {
        let constraints = [projectImageView.topAnchor.constraint(equalTo: topAnchor,
                                                                 constant: Constants.offset * 3),
                           projectImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                           projectImageView.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor,
                                                                  constant: Constants.offset),
                           rightAnchor.constraint(greaterThanOrEqualTo: projectImageView.rightAnchor,
                                                  constant: Constants.offset),
                           addFileButton.topAnchor.constraint(equalTo: projectImageView.bottomAnchor,
                                                              constant: Constants.offset),
                           addFileButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                           bottomAnchor.constraint(greaterThanOrEqualTo: addFileButton.bottomAnchor,
                                                   constant: Constants.offset),
                           dropView.topAnchor.constraint(equalTo: topAnchor),
                           dropView.leftAnchor.constraint(equalTo: leftAnchor),
                           rightAnchor.constraint(equalTo: dropView.rightAnchor),
                           bottomAnchor.constraint(equalTo: dropView.bottomAnchor),
                           settingsButton.topAnchor.constraint(equalTo: topAnchor,
                                                               constant: Constants.offset / 4),
                           rightAnchor.constraint(equalTo: settingsButton.rightAnchor,
                                                  constant: Constants.offset / 4),
                           settingsButton.widthAnchor.constraint(equalToConstant: Constants.settingsButtonSize.width),
                           settingsButton.heightAnchor.constraint(equalToConstant: Constants.settingsButtonSize.height)]
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapAddFileButton(_ sender: NSButton) {
        guard let window = window else { return }
        
        Task {
            let response = await openPanel.beginSheetModal(for: window)
            switch response {
            case .OK:
                guard let url = openPanel.url else { return }
                
                delegate?.fileSelected(url.path())
            default: break
            }
        }
    }
    
    @objc
    private func didTapSettings(_ sender: NSButton) {
        delegate?.didTapSettings()
    }
    
}
