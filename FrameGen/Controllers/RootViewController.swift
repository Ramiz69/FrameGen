//
//  RootViewController.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import AppKit

/// Shows the welcome screen or the opened project, and accepts projects dropped anywhere in the window.
final class RootViewController: NSViewController {

    // MARK: - Properties

    private let workspace: Workspace
    private let buildController: BuildController
    private var observation: ObservationLoop?
    private weak var shownProject: Project?
    private var isShowingWelcome = false

    // MARK: - Initial methods

    init(workspace: Workspace, buildController: BuildController) {
        self.workspace = workspace
        self.buildController = buildController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Life cycle

    override func loadView() {
        let dropView = DropTargetView()
        dropView.canAcceptDrop = { [weak self] in
            self?.workspace.project?.build.isRunning != true
        }
        dropView.onDrop = { [weak self] url in
            self?.open(url)
        }
        view = dropView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        observation = ObservationLoop { [weak self] in
            self?.showCurrentScreen()
        }
    }

    // MARK: - Private methods

    private func showCurrentScreen() {
        if let project = workspace.project {
            guard project !== shownProject else { return }

            shownProject = project
            isShowingWelcome = false
            setChild(ProjectViewController(project: project, buildController: buildController), in: view)
        } else {
            guard !isShowingWelcome else { return }

            shownProject = nil
            isShowingWelcome = true
            setChild(WelcomeViewController(workspace: workspace, openProject: { [weak self] url in self?.open(url) }), in: view)
        }
    }

    private func open(_ url: URL) {
        (view.window?.windowController as? MainWindowController)?.openProject(at: url)
    }

}
