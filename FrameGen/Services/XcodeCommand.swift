//
//  XcodeCommand.swift
//  FrameGen
//
//  Created by Рамиз Кичибеков on 21.04.2023.
//  Copyright © 2023 Ramiz Kichibekov. All rights reserved.
//

import Foundation

/// Builds the command lines FrameGen runs. Arguments are passed as an array,
/// so paths with spaces or quotes never need escaping.
nonisolated enum XcodeCommand {

    private static let xcodebuildURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
    private static let dittoURL = URL(fileURLWithPath: "/usr/bin/ditto")

    static func list(project: URL) -> ProcessRunner {
        ProcessRunner(executableURL: xcodebuildURL,
                      arguments: ["-list", "-json", "-project", project.path],
                      mergesStandardError: false)
    }

    static func archive(project: URL,
                        scheme: String,
                        configuration: String,
                        platform: Platform,
                        archiveURL: URL) -> ProcessRunner {
        ProcessRunner(executableURL: xcodebuildURL,
                      arguments: ["archive",
                                  "-project", project.path,
                                  "-scheme", scheme,
                                  "-configuration", configuration,
                                  "-destination", platform.destination,
                                  "-archivePath", archiveURL.path,
                                  "SKIP_INSTALL=NO",
                                  "BUILD_LIBRARIES_FOR_DISTRIBUTION=YES",
                                  // Recent Xcode versions no longer derive these from BUILD_LIBRARIES_FOR_DISTRIBUTION,
                                  // and -create-xcframework refuses Swift frameworks without a .swiftinterface.
                                  "SWIFT_ENABLE_LIBRARY_EVOLUTION=YES",
                                  "SWIFT_EMIT_MODULE_INTERFACE=YES"])
    }

    static func createXCFramework(slices: [XCFrameworkBuilder.Slice], output: URL) -> ProcessRunner {
        let sliceArguments = slices.flatMap { slice in
            ["-framework", slice.frameworkURL.path] + slice.debugSymbolURLs.flatMap { ["-debug-symbols", $0.path] }
        }

        return ProcessRunner(executableURL: xcodebuildURL,
                             arguments: ["-create-xcframework"] + sliceArguments + ["-output", output.path])
    }

    static func zip(source: URL, destination: URL) -> ProcessRunner {
        ProcessRunner(executableURL: dittoURL,
                      arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", source.path, destination.path])
    }

}
