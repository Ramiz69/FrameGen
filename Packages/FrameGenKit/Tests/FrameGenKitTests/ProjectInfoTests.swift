//
//  ProjectInfoTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Reading xcodebuild -list -json")
struct ProjectInfoTests {

    private func decode(_ json: String) throws -> ProjectInfo {
        try JSONDecoder().decode(ProjectInfo.self, from: Data(json.utf8))
    }

    // MARK: - Projects

    @Test("Reads schemes and configurations")
    func readsSchemesAndConfigurations() throws {
        let info = try decode("""
        {
          "project" : {
            "configurations" : ["Debug", "Release", "Staging"],
            "name" : "Kit",
            "schemes" : ["Kit", "KitTests"],
            "targets" : ["Kit"]
          }
        }
        """)

        #expect(info.schemes == ["Kit", "KitTests"])
        #expect(info.configurations == ["Debug", "Release", "Staging"])
    }

    @Test("Falls back to Release when a project's configurations are missing or empty", arguments: [
        #"{ "project" : { "schemes" : ["Kit"] } }"#,
        #"{ "project" : { "configurations" : [], "schemes" : ["Kit"] } }"#,
    ])
    func defaultsConfiguration(json: String) throws {
        let info = try decode(json)

        #expect(info.configurations == ["Release"])
        #expect(info.schemes == ["Kit"])
    }

    @Test("A project without schemes has an empty list")
    func missingSchemes() throws {
        let info = try decode(#"{ "project" : { "configurations" : ["Release"] } }"#)

        #expect(info.schemes.isEmpty)
    }

    // MARK: - Workspaces

    @Test("Workspace output is read, with Debug and Release as configurations")
    func readsWorkspaceOutput() throws {
        let info = try decode("""
        {
          "workspace" : {
            "name" : "App",
            "schemes" : ["App", "Pods-App", "Kit"]
          }
        }
        """)

        #expect(info.schemes == ["App", "Pods-App", "Kit"])
        #expect(info.configurations == ["Debug", "Release"])
    }

    @Test("Workspace configurations are used when present")
    func workspaceConfigurations() throws {
        let info = try decode(#"{ "workspace" : { "name" : "App", "schemes" : ["App"], "configurations" : ["Beta"] } }"#)

        #expect(info.configurations == ["Beta"])
    }

    @Test("A workspace with empty configurations falls back to Debug and Release")
    func workspaceEmptyConfigurations() throws {
        let info = try decode(#"{ "workspace" : { "name" : "App", "schemes" : [], "configurations" : [] } }"#)

        #expect(info.schemes.isEmpty)
        #expect(info.configurations == ["Debug", "Release"])
    }

    @Test("Output with neither a project nor a workspace is rejected", arguments: [
        "{}",
        #"{ "target" : { "schemes" : ["Kit"] } }"#,
        "[]",
    ])
    func rejectsUnknownOutput(json: String) {
        #expect(throws: DecodingError.self) {
            try decode(json)
        }
    }

    // MARK: - mainProject(inWorkspace:)

    private func makeWorkspace(_ fileRefs: [String], in directory: TemporaryDirectory, name: String = "App.xcworkspace") throws -> URL {
        let references = fileRefs.map { "   <FileRef\n      location = \"\($0)\">\n   </FileRef>" }.joined(separator: "\n")
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Workspace
           version = "1.0">
        \(references)
        </Workspace>

        """
        try directory.makeFile("\(name)/contents.xcworkspacedata", contents: Data(xml.utf8))

        return directory.url.appendingPathComponent(name)
    }

    @Test("mainProject skips Pods.xcodeproj and resolves group: paths against the workspace folder")
    func mainProjectSkipsPods() throws {
        let directory = try TemporaryDirectory()
        let workspace = try makeWorkspace(["group:Pods/Pods.xcodeproj", "group:Kit.xcodeproj"], in: directory)

        let project = try #require(ProjectInfo.mainProject(inWorkspace: workspace))

        #expect(project.path == directory.url.appendingPathComponent("Kit.xcodeproj").path)
    }

    @Test("mainProject resolves container: and self: paths against the workspace folder", arguments: ["container", "self"])
    func mainProjectRelativeLocations(kind: String) throws {
        let directory = try TemporaryDirectory()
        let workspace = try makeWorkspace(["\(kind):Sources/Kit.xcodeproj"], in: directory)

        let project = try #require(ProjectInfo.mainProject(inWorkspace: workspace))

        #expect(project.path == directory.url.appendingPathComponent("Sources/Kit.xcodeproj").path)
    }

    @Test("mainProject uses absolute: paths as is")
    func mainProjectAbsoluteLocation() throws {
        let directory = try TemporaryDirectory()
        let workspace = try makeWorkspace(["absolute:/Users/me/Elsewhere/Kit.xcodeproj"], in: directory)

        let project = try #require(ProjectInfo.mainProject(inWorkspace: workspace))

        #expect(project.path == "/Users/me/Elsewhere/Kit.xcodeproj")
    }

    @Test("mainProject returns the first non-Pods project and ignores other references")
    func mainProjectFirstProject() throws {
        let directory = try TemporaryDirectory()
        let workspace = try makeWorkspace(["group:README.md",
                                           "group:Pods/Pods.xcodeproj",
                                           "unknown:Other.xcodeproj",
                                           "group:Kit/Kit.xcodeproj",
                                           "group:Demo/Demo.xcodeproj"],
                                          in: directory)

        let project = try #require(ProjectInfo.mainProject(inWorkspace: workspace))

        #expect(project.path == directory.url.appendingPathComponent("Kit/Kit.xcodeproj").path)
    }

    @Test("mainProject is nil when the workspace only references Pods.xcodeproj")
    func mainProjectOnlyPods() throws {
        let directory = try TemporaryDirectory()
        let workspace = try makeWorkspace(["group:Pods/Pods.xcodeproj"], in: directory)

        #expect(ProjectInfo.mainProject(inWorkspace: workspace) == nil)
    }

    @Test("mainProject is nil without a readable contents.xcworkspacedata")
    func mainProjectMissingData() throws {
        let directory = try TemporaryDirectory()
        let empty = try directory.makeDirectory("Empty.xcworkspace")
        try directory.makeFile("Broken.xcworkspace/contents.xcworkspacedata", contents: Data("not xml <<<".utf8))

        #expect(ProjectInfo.mainProject(inWorkspace: empty) == nil)
        #expect(ProjectInfo.mainProject(inWorkspace: directory.url.appendingPathComponent("Broken.xcworkspace")) == nil)
        #expect(ProjectInfo.mainProject(inWorkspace: directory.url.appendingPathComponent("Missing.xcworkspace")) == nil)
    }

}
