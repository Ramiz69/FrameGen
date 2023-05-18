//
//  SettingsViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 26.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Cocoa

protocol SettingsViewInputProtocol: AnyObject {
    
    var presenter: SettingsPresenterOutputProtocol { get }
    
}

final class SettingsViewController: NSViewController, SettingsViewInputProtocol {
    
    // MARK: - Properties
    
    let presenter: SettingsPresenterOutputProtocol
    
    private let contentView = SettingsContentView()
    
    // MARK: - Initial methods
    
    required init(presenter: SettingsPresenterOutputProtocol) {
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
        
        contentView.frame = NSRect(x: .zero, y: .zero,
                                   width: presentingView.frame.width * 1.6,
                                   height: presentingView.frame.height * 0.4)
        view = contentView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureController()
    }
    
    // MARK: - Private methods
    
    private func configureController() {
        contentView.delegate = self
    }
    
}
