//
//  ProjectViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Shows the screen that matches the build phase: configuration, progress, result or failure.
final class ProjectViewController: NSViewController {

    private enum Screen {
        case configuration, progress, result, failure
    }

    // MARK: - Properties

    private let project: Project
    private let buildController: BuildController
    private var observation: ObservationLoop?
    private var screen: Screen?

    // MARK: - Initial methods

    init(project: Project, buildController: BuildController) {
        self.project = project
        self.buildController = buildController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observation = ObservationLoop { [weak self] in
            self?.showCurrentScreen()
        }
    }

    // MARK: - Private methods

    private func showCurrentScreen() {
        let next: Screen
        switch project.build.phase {
        case .idle:
            next = .configuration
        case .running:
            next = .progress
        case .succeeded:
            next = .result
        case .failed:
            next = .failure
        }
        guard next != screen else { return }

        screen = next
        let controller: NSViewController
        switch next {
        case .configuration:
            controller = ConfigurationViewController(project: project)
        case .progress:
            controller = BuildProgressViewController(project: project)
        case .result:
            controller = BuildResultViewController(project: project, buildController: buildController)
        case .failure:
            controller = BuildFailureViewController(project: project)
        }
        setChild(controller, in: view)
    }

}
