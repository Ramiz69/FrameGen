//
//  GitRemoteTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Parsing Git remotes and publish presets")
struct GitRemoteTests {

    struct Sample: Sendable, CustomTestStringConvertible {
        let remote: String
        let host: String
        let path: String

        var testDescription: String { remote.debugDescription }
    }

    static let validSamples: [Sample] = [
        .init(remote: "git@github.com:owner/repo.git", host: "github.com", path: "owner/repo"),
        .init(remote: "git@github.com:owner/repo", host: "github.com", path: "owner/repo"),
        .init(remote: "git@gitlab.company.com:group/sub/repo.git", host: "gitlab.company.com", path: "group/sub/repo"),
        .init(remote: "ssh://git@bitbucket.company.com:7999/o/r.git", host: "bitbucket.company.com", path: "o/r"),
        .init(remote: "ssh://git@github.com/owner/repo.git", host: "github.com", path: "owner/repo"),
        .init(remote: "https://github.com/owner/repo.git", host: "github.com", path: "owner/repo"),
        .init(remote: "https://github.com/owner/repo", host: "github.com", path: "owner/repo"),
        .init(remote: "https://github.com/owner/repo/", host: "github.com", path: "owner/repo"),
        .init(remote: "https://gitlab.com/group/sub/repo", host: "gitlab.com", path: "group/sub/repo"),
        .init(remote: "https://gitlab.com/group/sub/repo.git", host: "gitlab.com", path: "group/sub/repo"),
        .init(remote: "http://git.internal/team/repo.git", host: "git.internal", path: "team/repo"),
        .init(remote: "git://git.example.org/team/repo.git", host: "git.example.org", path: "team/repo"),
        .init(remote: "git@github.com:owner/repo.git\n", host: "github.com", path: "owner/repo"),
        .init(remote: "  https://github.com/owner/repo.git \n", host: "github.com", path: "owner/repo"),
        .init(remote: "https://user@github.com/owner/repo.git", host: "github.com", path: "owner/repo"),
    ]

    @Test("Parses SSH, scp-style and HTTPS remotes", arguments: validSamples)
    func parses(sample: Sample) throws {
        let remote = try #require(GitRemote(remoteURL: sample.remote))

        #expect(remote.host == sample.host)
        #expect(remote.path == sample.path)
    }

    @Test("Rejects remotes without an owner and a repository", arguments: [
        "",
        "   \n",
        "git@github.com:repo.git",
        "https://github.com/repo",
        "https://github.com/",
        "https://github.com",
        "ssh://git@host:7999/repo.git",
        "/Users/me/repos/kit.git",
        "../kit",
        "ftp://example.com/o/r",
        "file:///Users/me/o/r.git",
        "not a remote",
        "git@:o/r",
    ])
    func rejects(remote: String) {
        #expect(GitRemote(remoteURL: remote) == nil)
    }

    @Test("isGitHub is only true for github.com")
    func isGitHub() throws {
        #expect(try #require(GitRemote(remoteURL: "git@github.com:o/r.git")).isGitHub)
        #expect(try #require(GitRemote(remoteURL: "https://github.com/o/r")).isGitHub)
        #expect(try #require(GitRemote(remoteURL: "https://gitlab.com/o/r")).isGitHub == false)
        #expect(try #require(GitRemote(remoteURL: "git@github.company.com:o/r.git")).isGitHub == false)
    }

    @Test("origin(of:) reads the origin remote of a Git repository")
    func originOfRepository() async throws {
        let directory = try TemporaryDirectory()
        let git = ProcessRunner(executableURL: URL(fileURLWithPath: "/usr/bin/git"), arguments: [])
        for arguments in [["init", "-q"], ["remote", "add", "origin", "git@github.com:o/r.git"]] {
            var runner = git
            runner.arguments = ["-C", directory.url.path] + arguments
            _ = try await runner.output()
        }

        let remote = await GitRemote.origin(of: directory.url)

        #expect(remote == GitRemote(host: "github.com", path: "o/r"))
    }

    @Test("origin(of:) is nil outside a repository")
    func originOutsideRepository() async throws {
        let directory = try TemporaryDirectory()

        #expect(await GitRemote.origin(of: directory.url) == nil)
    }

    // MARK: - PublishPreset

    @Test("Every preset's command uploads the zip by {path} or {zip}", arguments: PublishPreset.allCases)
    func presetCommandUsesZip(preset: PublishPreset) {
        #expect(preset.commandTemplate.contains("{path}") || preset.commandTemplate.contains("{zip}"))
    }

    @Test("Every preset's download URL uses {zip} and only known placeholders", arguments: PublishPreset.allCases)
    func presetURLUsesZip(preset: PublishPreset) {
        let url = preset.downloadURLTemplate

        #expect(url.contains("{zip}"))
        #expect(url.hasPrefix("https://"))
        let used = url.matches(of: /\{([a-z]+)\}/).map { String($0.output.1) }
        #expect(used.allSatisfy(Template.placeholders.contains))
        #expect(!used.contains("path"))
    }

    @Test("Preset templates have no values missing when name, version and zip are known", arguments: PublishPreset.allCases)
    func presetsFillable(preset: PublishPreset) {
        let values = Template.Values(name: "Kit", version: "1.0", zip: "Kit.xcframework.zip", path: "/tmp/Kit.xcframework.zip", checksum: "c")

        #expect(Template(preset.commandTemplate).missingValues(for: values).isEmpty)
        #expect(Template(preset.downloadURLTemplate).missingValues(for: values).isEmpty)
    }

}
