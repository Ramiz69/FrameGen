//
//  ProjectLocatorTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Finding the project or workspace in a dropped item")
struct ProjectLocatorTests {

    // MARK: - Containers

    @Test("A project file without a workspace is used as is")
    func projectFile() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("Kit.xcodeproj")

        let container = try #require(ProjectLocator.container(for: project))

        #expect(container.url.path == project.path)
        #expect(container.kind == .project)
    }

    @Test("A workspace file is used as is")
    func workspaceFile() throws {
        let directory = try TemporaryDirectory()
        let workspace = try directory.makeDirectory("App.xcworkspace")

        let container = try #require(ProjectLocator.container(for: workspace))

        #expect(container.url.path == workspace.path)
        #expect(container.kind == .workspace)
    }

    @Test("A project with a sibling workspace of the same name resolves to the workspace")
    func prefersSiblingWorkspace() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("App/Kit.xcodeproj")
        let workspace = try directory.makeDirectory("App/Kit.xcworkspace")

        let container = try #require(ProjectLocator.container(for: project))

        #expect(container.url.path == workspace.path)
        #expect(container.kind == .workspace)
    }

    @Test("A workspace with a different name doesn't replace a dropped project")
    func ignoresDifferentlyNamedWorkspace() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("App/Kit.xcodeproj")
        try directory.makeDirectory("App/Other.xcworkspace")

        let container = try #require(ProjectLocator.container(for: project))

        #expect(container.url.path == project.path)
        #expect(container.kind == .project)
    }

    @Test("The workspace inside a project maps back to the project")
    func embeddedWorkspaceMapsToProject() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("Kit.xcodeproj")
        let embedded = try directory.makeDirectory("Kit.xcodeproj/project.xcworkspace")

        let container = try #require(ProjectLocator.container(for: embedded))

        #expect(container.url.path == project.path)
        #expect(container.kind == .project)
    }

    // MARK: - Folders

    @Test("A project directly inside the folder is found")
    func topLevelProject() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("Kit/Kit.xcodeproj")

        let container = try #require(ProjectLocator.container(for: directory.url.appendingPathComponent("Kit")))

        #expect(container.url.path == project.path)
        #expect(container.kind == .project)
    }

    @Test("In a folder, a workspace beats a project at the same level")
    func folderPrefersWorkspace() throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Repo/App.xcodeproj")
        let workspace = try directory.makeDirectory("Repo/App.xcworkspace")

        let container = try #require(ProjectLocator.container(for: directory.url.appendingPathComponent("Repo")))

        #expect(container.url.path == workspace.path)
        #expect(container.kind == .workspace)
    }

    @Test("In a folder, a workspace with another name still beats the project")
    func folderPrefersAnyWorkspace() throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Repo/AAA.xcodeproj")
        let workspace = try directory.makeDirectory("Repo/ZZZ.xcworkspace")

        let container = try #require(ProjectLocator.container(for: directory.url.appendingPathComponent("Repo")))

        #expect(container.url.path == workspace.path)
        #expect(container.kind == .workspace)
    }

    @Test("A shallow project beats a deeper workspace")
    func shallowProjectBeatsDeepWorkspace() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("Repo/Kit.xcodeproj")
        try directory.makeDirectory("Repo/Examples/Demo.xcworkspace")

        let container = try #require(ProjectLocator.container(for: directory.url.appendingPathComponent("Repo")))

        #expect(container.url.path == project.path)
        #expect(container.kind == .project)
    }

    @Test("A nested project is found, preferring the shallowest one")
    func nestedProject() throws {
        let directory = try TemporaryDirectory()
        let shallow = try directory.makeDirectory("Repo/Sources/Kit.xcodeproj")
        try directory.makeDirectory("Repo/Examples/Demo/Demo/Demo.xcodeproj")

        let container = try #require(ProjectLocator.container(for: directory.url.appendingPathComponent("Repo")))

        #expect(container.url.path == shallow.path)
        #expect(container.kind == .project)
    }

    @Test("Projects deeper than the search limit are ignored")
    func depthLimit() throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Repo/a/b/c/Kit.xcodeproj")
        let root = directory.url.appendingPathComponent("Repo")

        #expect(ProjectLocator.container(for: root, maxDepth: 3) == nil)
        #expect(ProjectLocator.container(for: root, maxDepth: 4) != nil)
    }

    @Test("Package contents, folders with extensions and hidden folders aren't searched")
    func skipsPackagesAndHiddenFolders() throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Repo/.build/Kit.xcodeproj")
        try directory.makeDirectory("Repo/.hidden/Nested/Kit.xcworkspace")
        try directory.makeDirectory("Repo/Tool.app/Contents/Kit.xcodeproj")
        try directory.makeDirectory("Repo/Resources.bundle/Kit.xcodeproj")

        #expect(ProjectLocator.container(for: directory.url.appendingPathComponent("Repo")) == nil)
    }

    @Test("Files, missing paths and the root folder aren't projects")
    func invalidItems() throws {
        let directory = try TemporaryDirectory()
        let file = try directory.makeFile("notes.txt")

        #expect(ProjectLocator.container(for: file) == nil)
        #expect(ProjectLocator.container(for: directory.url.appendingPathComponent("missing")) == nil)
        #expect(ProjectLocator.container(for: URL(fileURLWithPath: "/")) == nil)
    }

}
