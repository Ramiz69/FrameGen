//
//  OptionsViewController.swift
//  Frameworks generate
//
//  Created by Рамиз Кичибеков on 22.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

protocol OptionsViewInputProtocol: AnyObject {
    var presenter: OptionsPresenterOutputProtocol { get }
    func updateData(_ data: (configurations: [String], schemes: [String]))
    func scriptsDidCompete(with error: Error?, message: String?)
}

final class OptionsViewController: NSViewController, OptionsViewInputProtocol {
    
    // MARK: - Properties
    
    let presenter: OptionsPresenterOutputProtocol
    private(set) var data: (configurations: [String], schemes: [String]) = ([], []) {
        didSet {
            contentView.insertItems(data)
        }
    }
    private(set) lazy var contentView = OptionsContentView(delegate: self)
    
    // MARK: - Initial methods
    
    required init(presenter: OptionsPresenterOutputProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: .main)
    }
    
    @available(*, unavailable)
    init() {
        fatalError("init has not been implemented")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Life cycle
    
    override func loadView() {
        guard let presentingView = presentingViewController?.view else {
            super.loadView()
            
            return
        }
        
        view = NSView(frame: NSRect(x: .zero, y: .zero,
                                    width: presentingView.frame.width * 1.4,
                                    height: presentingView.frame.height * 0.6))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureController()
        configureConstraints() 
    }
    
    // MARK: - Public methods
    
    func updateData(_ data: (configurations: [String], schemes: [String])) {
        self.data = data
    }
    
    func scriptsDidCompete(with error: Error?, message: String?) {
        defer {
            contentView.stopIndicators()
        }
        
        if let error {
            let alert = NSAlert(error: error)
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            let alert = NSAlert()
            alert.alertStyle = .informational
            if let message {
                alert.informativeText = message
            }
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // MARK: - Private methods
    
    private func configureController() {
        presenter.makeDataFromProject()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
    }
    
    private func configureConstraints() {
        let constraints = [contentView.topAnchor.constraint(equalTo: view.topAnchor),
                           contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
                           view.rightAnchor.constraint(equalTo: contentView.rightAnchor),
                           view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)]
        NSLayoutConstraint.activate(constraints)
    }
    
}
