//
//  ProjectLocatorTests.swift
//  FrameGenTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGen

@MainActor
@Suite("Finding the project in a dropped item")
struct ProjectLocatorTests {

    @Test("A project file is used as is")
    func projectFile() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("Kit.xcodeproj")

        #expect(ProjectLocator.projectFile(for: project) == project)
    }

    @Test("A project directly inside the folder is found")
    func topLevelProject() throws {
        let directory = try TemporaryDirectory()
        let project = try directory.makeDirectory("Kit/Kit.xcodeproj")

        #expect(ProjectLocator.projectFile(for: directory.url.appendingPathComponent("Kit"))?.standardizedFileURL
                == project.standardizedFileURL)
    }

    @Test("A nested project is found, preferring the shallowest one")
    func nestedProject() throws {
        let directory = try TemporaryDirectory()
        let shallow = try directory.makeDirectory("Repo/Sources/Kit.xcodeproj")
        try directory.makeDirectory("Repo/Examples/Demo/Demo/Demo.xcodeproj")

        let found = ProjectLocator.projectFile(for: directory.url.appendingPathComponent("Repo"))

        #expect(found?.standardizedFileURL == shallow.standardizedFileURL)
    }

    @Test("Projects deeper than the search limit are ignored")
    func depthLimit() throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Repo/a/b/c/Kit.xcodeproj")
        let root = directory.url.appendingPathComponent("Repo")

        #expect(ProjectLocator.projectFile(for: root, maxDepth: 3) == nil)
        #expect(ProjectLocator.projectFile(for: root, maxDepth: 4) != nil)
    }

    @Test("Package contents and hidden folders aren't searched")
    func skipsPackagesAndHiddenFolders() throws {
        let directory = try TemporaryDirectory()
        try directory.makeDirectory("Repo/.build/Kit.xcodeproj")
        try directory.makeDirectory("Repo/Tool.app/Contents/Kit.xcodeproj")

        #expect(ProjectLocator.projectFile(for: directory.url.appendingPathComponent("Repo")) == nil)
    }

    @Test("Files and missing paths aren't projects")
    func invalidItems() throws {
        let directory = try TemporaryDirectory()
        let file = try directory.makeFile("notes.txt")

        #expect(ProjectLocator.projectFile(for: file) == nil)
        #expect(ProjectLocator.projectFile(for: directory.url.appendingPathComponent("missing")) == nil)
    }

}
