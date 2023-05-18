//
//  OptionsSchemeView.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 23.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

final class OptionsSchemeView: NSView {
    
    // MARK: - Properties
    
    private enum Constants {
        static let offset: CGFloat = 8
    }
    
    var completionHandler: ((Int) -> Void)?
    
    private let schemeLabel: NSTextField = {
        let label = NSTextField(labelWithString: "Choose a scheme:")
        label.translatesAutoresizingMaskIntoConstraints = false
        
        return label
    }()
    private lazy var schemeCombobox: NSComboBox = {
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
    
    func insertSchemes(_ schemes: [String]) {
        schemeCombobox.isEnabled = !schemes.isEmpty
        if !schemes.isEmpty {
            schemeCombobox.addItems(withObjectValues: schemes)
            schemeCombobox.selectItem(at: .zero)
            schemeCombobox.reloadData()
            completionHandler?(.zero)
        }
    }
    
    // MARK: - Private methods
    
    private func configureView() {
        addSubview(schemeLabel)
        addSubview(schemeCombobox)
    }
    
    private func configureConstraints() {
        let constraints = [schemeLabel.topAnchor.constraint(equalTo: topAnchor),
                           schemeLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
                           bottomAnchor.constraint(equalTo: schemeLabel.bottomAnchor),
                           schemeCombobox.centerYAnchor.constraint(equalTo: schemeLabel.centerYAnchor),
                           schemeCombobox.leftAnchor.constraint(equalTo: schemeLabel.rightAnchor,
                                                                constant: Constants.offset),
                           rightAnchor.constraint(equalTo: schemeCombobox.rightAnchor)]
        NSLayoutConstraint.activate(constraints)
    }
    
}
