//
//  TemplateTests.swift
//  FrameGenKitTests
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation
import Testing
@testable import FrameGenKit

@Suite("Download URL and publish command templates")
struct TemplateTests {

    private let values = Template.Values(name: "Kit",
                                         version: "1.2.0",
                                         zip: "Kit.xcframework.zip",
                                         path: "/Users/me/Build Output/Kit.xcframework.zip",
                                         checksum: "abc123")

    /// Runs `printf %s <argument>` through `/bin/sh -c` and returns exactly what the shell printed.
    /// The output goes to a file, because `ProcessRunner.output()` normalizes line endings.
    private func shellPrint(_ quotedArgument: String) async throws -> String {
        let directory = try TemporaryDirectory()
        let file = directory.url.appendingPathComponent("out.txt")
        let script = "printf %s \(quotedArgument) > \(ShellQuoting.quote(file.path))"
        _ = try await ProcessRunner(executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script]).output()

        return try String(contentsOf: file, encoding: .utf8)
    }

    // MARK: - missingValues

    @Test("The placeholder list is complete")
    func placeholders() {
        #expect(Template.placeholders == ["name", "version", "zip", "path", "checksum"])
    }

    @Test("missingValues is empty when every used placeholder has a value")
    func noMissingValues() {
        #expect(Template("https://cdn.example.com/{name}/{version}/{zip}?sum={checksum}&p={path}").missingValues(for: values).isEmpty)
    }

    @Test("missingValues lists placeholders without a value, in placeholder order")
    func missingValues() {
        let template = Template("{checksum}/{version}/{name}")
        let values = Template.Values(name: "Kit", version: nil, zip: "Kit.zip", path: "/Kit.zip", checksum: nil)

        #expect(template.missingValues(for: values) == ["version", "checksum"])
    }

    @Test("Unused optional values aren't missing")
    func unusedValuesArentMissing() {
        let values = Template.Values(name: "Kit", version: nil, zip: "Kit.zip", path: "/Kit.zip")

        #expect(Template("https://example.org/{zip}").missingValues(for: values).isEmpty)
    }

    // MARK: - url(with:)

    @Test("url fills every placeholder")
    func url() throws {
        let url = try Template("https://cdn.example.com/{name}/{version}/{zip}").url(with: values)

        #expect(url.absoluteString == "https://cdn.example.com/Kit/1.2.0/Kit.xcframework.zip")
    }

    @Test("url percent-encodes values")
    func urlPercentEncodes() throws {
        let values = Template.Values(name: "My Kit", version: "1.0 beta", zip: "My Kit.xcframework.zip", path: "/tmp/x")

        let url = try Template("https://cdn.example.com/{name}/{version}/{zip}").url(with: values)

        #expect(url.absoluteString == "https://cdn.example.com/My%20Kit/1.0%20beta/My%20Kit.xcframework.zip")
    }

    @Test("url accepts http and https in any case", arguments: ["http://example.com/{zip}", "HTTPS://example.com/{zip}", "https://example.com:8443/{zip}"])
    func urlAcceptsHTTP(template: String) throws {
        let url = try Template(template).url(with: values)

        #expect(url.absoluteString.hasSuffix("/Kit.xcframework.zip"))
    }

    @Test("url throws missingValues before building the URL")
    func urlMissingValues() {
        let values = Template.Values(name: "Kit", version: nil, zip: "Kit.zip", path: "/Kit.zip")

        #expect(throws: TemplateError.missingValues(["version"])) {
            try Template("https://cdn.example.com/{name}/{version}/{zip}").url(with: values)
        }
    }

    @Test("url rejects other schemes, missing hosts and garbage", arguments: [
        "ftp://example.com/{zip}",
        "file:///tmp/{zip}",
        "s3://bucket/{zip}",
        "example.com/{zip}",
        "/downloads/{zip}",
        "https:///{zip}",
        "",
    ])
    func urlRejectsInvalid(template: String) {
        #expect(throws: TemplateError.self) {
            try Template(template).url(with: values)
        }
    }

    @Test("Preset URLs with a <placeholder> host are invalid until edited", arguments: [PublishPreset.amazonS3, .artifactory])
    func urlRejectsAngleBracketHost(preset: PublishPreset) {
        #expect(throws: TemplateError.self) {
            try Template(preset.downloadURLTemplate).url(with: values)
        }
    }

    @Test("Preset URLs with a <placeholder> path are invalid until edited",
          arguments: [PublishPreset.gitLabPackageRegistry, .bitbucketDownloads])
    func urlRejectsAngleBracketPath(preset: PublishPreset) {
        #expect(throws: TemplateError.self) {
            try Template(preset.downloadURLTemplate).url(with: values)
        }
    }

    @Test("A URL with <placeholder> text in the path is invalid")
    func urlRejectsAngleBracketsInPath() {
        #expect(throws: TemplateError.self) {
            try Template("https://cdn.example.com/<folder>/{zip}").url(with: values)
        }
    }

    @Test("A URL with <placeholder> text throws invalidURL with the filled text")
    func urlInvalidURLCarriesText() {
        #expect(throws: TemplateError.invalidURL("https://<bucket>.s3.amazonaws.com/Kit/1.2.0/Kit.xcframework.zip")) {
            try Template("https://<bucket>.s3.amazonaws.com/{name}/{version}/{zip}").url(with: values)
        }
    }

    // MARK: - string(with:)

    @Test("string fills placeholders without any encoding or quoting")
    func string() throws {
        let values = Template.Values(name: "My Kit", version: "1.0 beta", zip: "My Kit.zip", path: "/a b/My Kit.zip", checksum: "c")

        #expect(try Template("v{version} {name} '{zip}' {path} {checksum}").string(with: values)
                == "v1.0 beta My Kit 'My Kit.zip' /a b/My Kit.zip c")
    }

    @Test("string keeps unknown braces and repeats placeholders")
    func stringUnknownBraces() throws {
        #expect(try Template("{name}-{name}-{unknown}").string(with: values) == "Kit-Kit-{unknown}")
    }

    @Test("string throws missingValues")
    func stringMissing() {
        let values = Template.Values(name: "Kit", version: nil, zip: "Kit.zip", path: "/Kit.zip")

        #expect(throws: TemplateError.missingValues(["version"])) {
            try Template("v{version}").string(with: values)
        }
    }

    // MARK: - command(with:)

    @Test("command shell-quotes values that need it and leaves safe ones alone")
    func command() throws {
        let command = try Template("aws s3 cp {path} s3://bucket/{name}/{version}/{zip}").command(with: values)

        #expect(command == "aws s3 cp '/Users/me/Build Output/Kit.xcframework.zip' s3://bucket/Kit/1.2.0/Kit.xcframework.zip")
    }

    @Test("command throws missingValues")
    func commandMissing() {
        let values = Template.Values(name: "Kit", version: "1", zip: "Kit.zip", path: "/Kit.zip")

        #expect(throws: TemplateError.missingValues(["checksum"])) {
            try Template("echo {checksum}").command(with: values)
        }
    }

    @Test("command passes a hostile value to the shell as one literal argument")
    func commandIsSafeInShell() async throws {
        let hostile = #"/tmp/a b/$(touch pwned)`id`;rm -rf "x" 'y' \ $HOME"#
        let values = Template.Values(name: "Kit", version: nil, zip: "Kit.zip", path: hostile)
        let argument = try Template("{path}").command(with: values)

        let output = try await shellPrint(argument)

        #expect(output == hostile)
    }

    // MARK: - ShellQuoting

    @Test("Safe values are not quoted", arguments: ["Kit", "Kit.xcframework.zip", "/usr/bin/xcodebuild", "a=b", "user@host:path", "50%", "a+b,c", "-v_1"])
    func quoteSafe(value: String) {
        #expect(ShellQuoting.quote(value) == value)
    }

    @Test("Unsafe values are single-quoted", arguments: [
        ("", "''"),
        ("a b", "'a b'"),
        ("$HOME", "'$HOME'"),
        ("it's", #"'it'\''s'"#),
        ("'", #"''\'''"#),
        ("a\nb", "'a\nb'"),
        ("~", "'~'"),
        ("*", "'*'"),
    ])
    func quoteUnsafe(value: String, expected: String) {
        #expect(ShellQuoting.quote(value) == expected)
    }

    @Test("Quoted values round-trip through /bin/sh unchanged", arguments: [
        "plain",
        "",
        "with space",
        "it's",
        "''",
        #"double "quotes""#,
        "$HOME and ${PATH}",
        "`id` $(id)",
        "back\\slash",
        "semi;colon && pipe | redirect > /dev/null",
        "glob * ? [a-z] ~",
        "new\nline\ttab",
        "unicode ✓ Рамиз",
        "!history #comment",
    ])
    func quoteRoundTrip(value: String) async throws {
        let output = try await shellPrint(ShellQuoting.quote(value))

        #expect(output == value)
    }

}
