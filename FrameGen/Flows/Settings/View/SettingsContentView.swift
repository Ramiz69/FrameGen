//
//  SettingsContentView.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa
import QuartzCore

protocol SettingsContentViewProtocol: AnyObject {
    
    func dismissView()
    func fileSelected(_ path: String)
    
}

final class SettingsContentView: NSView {
    
    // MARK: - Properties
    
    weak var delegate: SettingsContentViewProtocol?
    
    private enum Constants {
        static let offset: CGFloat = 32
        
        enum Checkbox {
            static let width: CGFloat = 75
        }
    }
    
    enum LocationType: Int, CaseIterable {
        case `default`
        case custom
        
        var title: String {
            switch self {
            case .default:
                return "Default"
            case .custom:
                return "Custom"
            }
        }
    }
    
    var locationType: LocationType = .default {
        didSet {
            pathView.updateState(locationType == .default ? .default : .custom)
        }
    }
    
    private let titleLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Locations")
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    private let archivesLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Archives:")
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    private lazy var typeCombobox: NSComboBox = {
        let box = NSComboBox()
        box.isEditable = false
        box.addItems(withObjectValues: LocationType.allCases.compactMap({ $0.title }))
        box.selectItem(at: .zero)
        box.isEnabled = true
        box.delegate = self
        box.shadow = NSShadow()
        box.translatesAutoresizingMaskIntoConstraints = false
        
        return box
    }()
    private(set) lazy var openPanel: NSOpenPanel = {
        let panel = NSOpenPanel(contentRect: frame, styleMask: .closable, backing: .buffered, defer: true)
        panel.worksWhenModal = true
        panel.title = "Choose a new location"
        panel.showsResizeIndicator = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        
        return panel
    }()
    private lazy var okButton: NSButton = {
        let button = NSButton(title: "OK",
                              target: self,
                              action: #selector(didTapOK(_ :)))
        button.bezelColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        
        return button
    }()
    private(set) lazy var pathView: PathView = {
        let view = PathView()
        view.delegate = self
        view.wantsLayer = true
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()
    
    // MARK: - Initial methods
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
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
        addSubview(titleLabel)
        addSubview(archivesLabel)
        addSubview(typeCombobox)
        addSubview(pathView)
        addSubview(okButton)
    }
    
    private func configureConstraints() {
        let constraints = [titleLabel.topAnchor.constraint(equalTo: topAnchor,
                                                           constant: Constants.offset / 4),
                           titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor,
                                                               constant: Constants.offset),
                           trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor,
                                                     constant: Constants.offset),
                           archivesLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor,
                                                              constant: Constants.offset / 2),
                           archivesLabel.leadingAnchor.constraint(equalTo: leadingAnchor,
                                                                  constant: Constants.offset),
                           typeCombobox.centerYAnchor.constraint(equalTo: archivesLabel.centerYAnchor),
                           typeCombobox.widthAnchor.constraint(equalToConstant: Constants.Checkbox.width),
                           typeCombobox.leftAnchor.constraint(equalTo: archivesLabel.rightAnchor,
                                                              constant: Constants.offset / 4),
                           pathView.topAnchor.constraint(equalTo: typeCombobox.topAnchor),
                           pathView.centerYAnchor.constraint(equalTo: typeCombobox.centerYAnchor),
                           pathView.leftAnchor.constraint(equalTo: typeCombobox.rightAnchor,
                                                          constant: Constants.offset / 4),
                           rightAnchor.constraint(equalTo: pathView.rightAnchor,
                                                  constant: Constants.offset),
                           pathView.bottomAnchor.constraint(equalTo: typeCombobox.bottomAnchor),
                           okButton.topAnchor.constraint(equalTo: archivesLabel.bottomAnchor,
                                                         constant: Constants.offset / 2),
                           okButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                           bottomAnchor.constraint(equalTo: okButton.bottomAnchor,
                                                   constant: Constants.offset / 2)]
        NSLayoutConstraint.activate(constraints)
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapOK(_ sender: NSButton) {
        delegate?.dismissView()
    }
    
}
