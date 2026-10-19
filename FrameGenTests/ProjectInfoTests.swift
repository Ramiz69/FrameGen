//
//  ProjectInfoTests.swift
//  FrameGenTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGen

@Suite("Reading xcodebuild -list -json")
struct ProjectInfoTests {

    private func decode(_ json: String) throws -> ProjectInfo {
        try JSONDecoder().decode(ProjectInfo.self, from: Data(json.utf8))
    }

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

    @Test("Falls back to Release when configurations are missing or empty", arguments: [
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

    @Test("Output without a project object is rejected")
    func rejectsWorkspaceOutput() {
        #expect(throws: DecodingError.self) {
            try decode(#"{ "workspace" : { "name" : "App", "schemes" : ["App"] } }"#)
        }
    }

}
