//
//  ProjectPicker.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 18.05.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import AppKit
import UniformTypeIdentifiers

/// Open panels for projects and folders. Finding the project inside a choice is FrameGenKit's `ProjectLocator`.
enum ProjectPicker {

    static let projectType = UTType("com.apple.xcode.project") ?? .package
    static let workspaceType = UTType("com.apple.dt.document.workspace") ?? .package

    static func chooseProject() -> URL? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Open Project")
        panel.message = String(localized: "Choose an Xcode project, a workspace or a folder that contains one.")
        panel.prompt = String(localized: "Open")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [workspaceType, projectType, .folder]

        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseFolder(title: String, startingAt directory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = String(localized: "Choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory

        return panel.runModal() == .OK ? panel.url : nil
    }

}
