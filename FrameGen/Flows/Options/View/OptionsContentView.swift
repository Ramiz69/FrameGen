//
//  OptionsContentView.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

protocol OptionsContentDelegate: AnyObject {
    func dismissView()
    func runScripts(_ scripts: [Script])
    func didSelectIndex(box: OptionsContentView.ComboboxType, at index: Int)
}

final class OptionsContentView: NSView {
    
    // MARK: - Properties
    
    private weak var delegate: OptionsContentDelegate?
    
    enum ComboboxType {
        case scheme, configuration
    }
    
    private enum Constants {
        static let offset: CGFloat = 32
    }
    
    private let schemeView = OptionsSchemeView()
    private let configurationView = OptionsConfigurationView()
    
    private let checkboxStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = .zero
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }()
    
    private let activityIndicator: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.isHidden = true
        indicator.isIndeterminate = true
        indicator.isDisplayedWhenStopped = true
        indicator.style = .spinning
        indicator.minValue = .zero
        indicator.maxValue = 100
        indicator.translatesAutoresizingMaskIntoConstraints = false
        
        return indicator
    }()
    
    private let buttonsStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = Constants.offset
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        return stack
    }()
    
    private lazy var cancelButton: NSButton = {
        let button = NSButton(title: "Cancel",
                              target: self,
                              action: #selector(didTapCancel(_ :)))
        
        return button
    }()
    private lazy var generateButton: NSButton = {
        let button = NSButton(title: "Generate",
                              target: self,
                              action: #selector(didTapGenerate(_ :)))
        button.bezelColor = .systemBlue
        button.isEnabled = false
        
        return button
    }()
    
    private var includeScripts: [Script] = [] {
        didSet {
            generateButton.isEnabled = !includeScripts.isEmpty
        }
    }
    
    // MARK: - Initial methods
    
    required init(delegate: OptionsContentDelegate?) {
        self.delegate = delegate
        super.init(frame: .zero)
        
        configureView()
        configureCheckboxes()
        configureConstraints()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public methods
    
    func insertItems(_ data: (configurations: [String], schemes: [String])) {
        schemeView.completionHandler = { [weak self] in
            self?.delegate?.didSelectIndex(box: .scheme, at: $0)
        }
        configurationView.completionHandler = { [weak self] in
            self?.delegate?.didSelectIndex(box: .configuration, at: $0)
        }
        schemeView.insertSchemes(data.schemes)
        configurationView.insertConfigurations(data.configurations)
    }
    
    func stopIndicators() {
        activityIndicator.stopAnimation(self)
        activityIndicator.isHidden = true
        generateButton.isEnabled = true
    }
    
    // MARK: - Private methods
    
    private func configureView() {
        schemeView.translatesAutoresizingMaskIntoConstraints = false
        configurationView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(schemeView)
        addSubview(configurationView)
        addSubview(activityIndicator)
        addSubview(checkboxStackView)
        addSubview(buttonsStackView)
        buttonsStackView.addArrangedSubview(cancelButton)
        buttonsStackView.addArrangedSubview(generateButton)
    }
    
    private func configureConstraints() {
        let constraints = [schemeView.topAnchor.constraint(equalTo: topAnchor,
                                                           constant: Constants.offset),
                           schemeView.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor,
                                                            constant: Constants.offset),
                           schemeView.centerXAnchor.constraint(equalTo: centerXAnchor),
                           rightAnchor.constraint(greaterThanOrEqualTo: schemeView.rightAnchor,
                                                  constant: Constants.offset),
                           configurationView.topAnchor.constraint(equalTo: schemeView.bottomAnchor,
                                                                  constant: Constants.offset / 2),
                           configurationView.leftAnchor.constraint(equalTo: schemeView.leftAnchor),
                           configurationView.centerXAnchor.constraint(equalTo: centerXAnchor),
                           schemeView.rightAnchor.constraint(equalTo: configurationView.rightAnchor),
                           activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                           activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
                           checkboxStackView.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor,
                                                                   constant: Constants.offset),
                           checkboxStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
                           rightAnchor.constraint(greaterThanOrEqualTo: checkboxStackView.rightAnchor,
                                                  constant: Constants.offset),
                           buttonsStackView.topAnchor.constraint(equalTo: checkboxStackView.bottomAnchor,
                                                                 constant: Constants.offset),
                           buttonsStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
                           buttonsStackView.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor,
                                                                  constant: Constants.offset),
                           rightAnchor.constraint(greaterThanOrEqualTo: buttonsStackView.rightAnchor,
                                                  constant: Constants.offset),
                           bottomAnchor.constraint(equalTo: buttonsStackView.bottomAnchor,
                                                   constant: Constants.offset)]
        NSLayoutConstraint.activate(constraints)
    }
    
    private func configureCheckboxes() {
        for index in 0..<3 {
            guard let type = CheckboxButton.CheckboxType(rawValue: index) else { return }
            
            let checkbox = CheckboxButton(type: type,
                                          target: self,
                                          action: #selector(didTapCheckbox(_ :)))
            checkboxStackView.addArrangedSubview(checkbox)
        }
    }
    
    private func configureScripts(_ sender: CheckboxButton) {
        let scriptType = sender.type.scriptType
        switch sender.state {
        case .on:
            if !includeScripts.contains(scriptType) {
                includeScripts.append(scriptType)
            }
        default:
            if includeScripts.contains(scriptType) {
                includeScripts.removeAll(where: { $0 == scriptType })
            }
        }
    }
    
    // MARK: - Actions
    
    @objc
    private func didTapCancel(_ sender: NSButton) {
        delegate?.dismissView()
    }
    
    @objc
    private func didTapGenerate(_ sender: NSButton) {
        sender.isEnabled = false
        activityIndicator.isHidden = false
        activityIndicator.startAnimation(self)
        delegate?.runScripts(includeScripts)
    }
    
    @objc
    private func didTapCheckbox(_ sender: CheckboxButton) {
        configureScripts(sender)
    }
    
}
