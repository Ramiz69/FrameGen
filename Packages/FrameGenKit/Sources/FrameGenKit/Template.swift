//
//  Template.swift
//  FrameGenKit
//
//  Created by Рамиз Кичибеков on 19.10.2026.
//  Copyright © 2026 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// Fills `{name}`, `{version}`, `{zip}`, `{checksum}` and `{path}` placeholders in download URL
/// and publish command templates.
public struct Template: Equatable, Sendable {

    public struct Values: Equatable, Sendable {
        /// The framework name, e.g. `Kit`.
        public var name: String
        public var version: String?
        /// The zip's file name, e.g. `Kit.xcframework.zip`.
        public var zip: String
        /// The zip's full path; only meaningful for commands.
        public var path: String
        public var checksum: String?

        public init(name: String, version: String?, zip: String, path: String, checksum: String? = nil) {
            self.name = name
            self.version = version
            self.zip = zip
            self.path = path
            self.checksum = checksum
        }
    }

    public let text: String

    public init(_ text: String) {
        self.text = text
    }

    public static let placeholders = ["name", "version", "zip", "path", "checksum"]

    /// Placeholders the template uses that the values can't fill, e.g. `{version}` without a version.
    public func missingValues(for values: Values) -> [String] {
        Self.placeholders.filter { text.contains("{\($0)}") && value(named: $0, in: values) == nil }
    }

    /// The download URL, with every value percent-encoded for use in a path.
    public func url(with values: Values) throws -> URL {
        let missing = missingValues(for: values)
        guard missing.isEmpty else { throw TemplateError.missingValues(missing) }

        let filled = fill(values) { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
        // Values are percent-encoded above, so any remaining angle brackets are unedited `<placeholder>` text
        // from a preset; URL(string:) would silently encode them instead of failing.
        guard
            !filled.contains("<"), !filled.contains(">"),
            let url = URL(string: filled),
            let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme), url.host != nil
        else {
            throw TemplateError.invalidURL(filled)
        }

        return url
    }

    /// Plain text, e.g. a release tag like `v{version}`.
    public func string(with values: Values) throws -> String {
        let missing = missingValues(for: values)
        guard missing.isEmpty else { throw TemplateError.missingValues(missing) }
        
        return fill(values) { $0 }
    }
    
    /// A shell command, with every value single-quoted so it is passed as one argument.
    public func command(with values: Values) throws -> String {
        let missing = missingValues(for: values)
        guard missing.isEmpty else { throw TemplateError.missingValues(missing) }

        return fill(values, transform: ShellQuoting.quote)
    }

    // MARK: - Private methods

    private func fill(_ values: Values, transform: (String) -> String) -> String {
        Self.placeholders.reduce(text) { result, placeholder in
            guard let value = value(named: placeholder, in: values) else { return result }

            return result.replacingOccurrences(of: "{\(placeholder)}", with: transform(value))
        }
    }

    private func value(named placeholder: String, in values: Values) -> String? {
        switch placeholder {
        case "name":
            return values.name
        case "version":
            return values.version
        case "zip":
            return values.zip
        case "path":
            return values.path
        case "checksum":
            return values.checksum
        default:
            return nil
        }
    }

}

public enum TemplateError: LocalizedError, Equatable {
    case missingValues([String])
    case invalidURL(String)

    public var errorDescription: String? {
        switch self {
        case .missingValues(let names):
            return "The template uses \(names.map { "{\($0)}" }.joined(separator: ", ")), but no value is set for it."
        case .invalidURL(let url):
            return "“\(url)” isn't a valid http or https URL."
        }
    }
}

public enum ShellQuoting {

    /// Quotes a value for zsh/bash unless it only contains characters that are safe as is.
    public static func quote(_ value: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./=:@%+,")
        if !value.isEmpty, value.unicodeScalars.allSatisfy(safe.contains) {
            return value
        }

        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

}
