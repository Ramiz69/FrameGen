//
//  OptionsConfigurationView.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 23.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

final class OptionsConfigurationView: NSView {
    
    // MARK: - Properties
    
    private enum Constants {
        static let offset: CGFloat = 8
    }
    
    var completionHandler: ((Int) -> Void)?
    
    private let configurationLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Choose a configuration:")
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    private lazy var configurationCombobox: NSComboBox = {
        let box = NSComboBox()
        box.isEditable = false
        box.isEnabled = true
        box.delegate = self
        box.translatesAutoresizingMaskIntoConstraints = false
        
        return box
    }()
    
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
    
    // MARK: - Public methods
    
    func insertConfigurations(_ configurations: [String]) {
        configurationCombobox.isEnabled = !configurations.isEmpty
        if !configurations.isEmpty {
            configurationCombobox.addItems(withObjectValues: configurations)
            configurationCombobox.selectItem(at: .zero)
            configurationCombobox.reloadData()
            completionHandler?(.zero)
        }
    }
    
    // MARK: - Private methods
    
    private func configureView() {
        addSubview(configurationLabel)
        addSubview(configurationCombobox)
    }
    
    private func configureConstraints() {
        let constraints = [configurationLabel.topAnchor.constraint(equalTo: topAnchor),
                           configurationLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
                           bottomAnchor.constraint(equalTo: configurationLabel.bottomAnchor),
                           configurationCombobox.centerYAnchor.constraint(equalTo: configurationLabel.centerYAnchor),
                           configurationCombobox.leftAnchor.constraint(equalTo: configurationLabel.rightAnchor,
                                                                       constant: Constants.offset),
                           rightAnchor.constraint(equalTo: configurationCombobox.rightAnchor)]
        NSLayoutConstraint.activate(constraints)
    }
    
}
