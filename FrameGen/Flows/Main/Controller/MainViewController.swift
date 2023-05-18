//
//  MainViewController.swift
//  generateFramework
//
//  Created by Рамиз Кичибеков on 08.04.2023.
//

import Cocoa

protocol MainViewInputProtocol: AnyObject {
    
    var presenter: MainPresenterOutputProtocol { get }
    
    func openOptions(path: String)
    func openSettings()
    
}

final class MainViewController: NSViewController, MainViewInputProtocol {
    
    // MARK: - Properties
    
    private let contentView = ContentView()
    private let frame: NSRect
    let presenter: MainPresenterOutputProtocol
    
    // MARK: - Initial methods
    
    required init(frame: NSRect, presenter: MainPresenterOutputProtocol) {
        self.presenter = presenter
        self.frame = frame
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
        let visualEffectView = NSVisualEffectView(frame: frame)
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .fullScreenUI
        view = visualEffectView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureController()
        configureLayout()
    }
    
    // MARK: - Public methods
    
    func openOptions(path: String) {
        let optionsController = AppBuilder.createOptionsModule(path: path)
        presentAsSheet(optionsController)
    }
    
    func openSettings() {
        let settingsController = AppBuilder.createSettingsModule()
        presentAsSheet(settingsController)
    }
    
    // MARK: - Private methods
    
    private func configureController() {
        contentView.delegate = self
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentView)
    }
    
    private func configureLayout() {
        let constraints = [contentView.topAnchor.constraint(equalTo: view.topAnchor),
                           contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
                           view.rightAnchor.constraint(equalTo: contentView.rightAnchor),
                           view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)]
        NSLayoutConstraint.activate(constraints)
    }
    
}
