# <img src="image/appIcon.png" width="100" height="100" alt=""> FrameGen

FrameGen is a Mac app that turns an Xcode framework project into a distributable **XCFramework**. Pick a scheme and the platforms, press Build, and FrameGen archives every platform, assembles the XCFramework with its debug symbols, zips it and gives you a ready-to-paste Swift Package Manager `binaryTarget`.

<img src="image/configuration.png" width="600" alt="Project options: scheme, configuration, platforms and output folder">

## Features

- **One-click XCFramework.** Runs `xcodebuild archive` for each selected platform, then `xcodebuild -create-xcframework` with the dSYM of every slice.
- **Ready for SwiftPM.** Zips the XCFramework, computes its checksum and writes a `.binaryTarget(...)` snippet next to it.
- **Privacy manifest check.** Warns when a slice ships without `PrivacyInfo.xcprivacy`, which Apple requires in commonly used third-party SDKs.
- **Live progress.** Shows each step with its status and duration, the current xcodebuild action and the full build log.
- **Readable failures.** Shows which step failed and pulls the compiler `error:` lines out of the log.
- **Remembers your choices.** Keeps the scheme, configuration, platforms and output folder of every project, plus a list of recent projects.
- **A native Mac app.** Menu bar commands with keyboard shortcuts, a toolbar, drag and drop, Dark Mode and VoiceOver labels.

Supported platforms: iOS, iOS Simulator and Mac Catalyst.

## Screenshots

| Start | Building |
| --- | --- |
| <img src="image/welcome.png" width="400" alt="Welcome screen with recent projects"> | <img src="image/progress.png" width="400" alt="Build progress with steps and log"> |

<img src="image/result.png" width="600" alt="Result with files, checksum and binaryTarget snippet">

## Requirements

- A Mac with Apple silicon running macOS 27 or later.
- Xcode 27 or later, selected with `xcode-select`.
- A project with a shared framework scheme.

## Usage

1. Open a project with **File › Open Project…** (⌘O), pick one from **Recent Projects**, or drop an `.xcodeproj` or its folder onto the window or the Dock icon.
2. Choose the scheme, the configuration and the platforms.
3. Press **Build XCFramework** (⌘B). Stop a build with ⌘. or Esc.
4. When the build finishes, use **Show in Finder**, copy the checksum or copy the `binaryTarget` snippet.

FrameGen writes these files to `build/` next to the project. You can choose another folder per project, or set a shared default in **Settings** (⌘,).

```
build/
├── SampleKit.xcframework
├── SampleKit.xcframework.zip
├── SampleKit.binaryTarget.txt
└── Archives/            # one .xcarchive per platform; optional, see Settings
```

Archives are built with `SKIP_INSTALL=NO`, `BUILD_LIBRARIES_FOR_DISTRIBUTION=YES`, `SWIFT_ENABLE_LIBRARY_EVOLUTION=YES` and `SWIFT_EMIT_MODULE_INTERFACE=YES`, so Swift frameworks get the module interfaces that `-create-xcframework` needs.

### Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Open Project | ⌘O |
| Close Project | ⇧⌘W |
| Build XCFramework | ⌘B |
| Stop | ⌘. |
| Show Output in Finder | ⇧⌘R |
| Settings | ⌘, |

## Building from source

Open `FrameGen.xcodeproj` in Xcode 27 and run the **FrameGen** scheme, or build it from the command line:

```bash
xcodebuild -project FrameGen.xcodeproj -scheme FrameGen -configuration Release build
```

The app runs `xcodebuild` on your projects, so it can't use the App Sandbox. That also means it can't ship on the Mac App Store. Distribute it signed with a Developer ID and notarized.

## Architecture

FrameGen uses AppKit with Apple's Model-View-Controller pattern and Swift 6 concurrency. The main actor is the default isolation.

| Layer | Contents |
| --- | --- |
| `Models` | `Workspace`, `Project` and `BuildState` are `@Observable` classes; `Platform` and `ProjectInfo` are value types. |
| `Controllers` | `NSViewController` subclasses for every screen, plus `BuildController`, which runs the build pipeline with `async`/`await` and task cancellation. |
| `Views` | Reusable `NSView` subclasses: form sections, step rows, log view, callouts, drop target. |
| `Services` | `ProcessRunner` streams process output as an `AsyncThrowingStream`. `XcodeCommand` builds the xcodebuild command lines. `XCFrameworkBuilder` finds the slices, computes the checksum and checks privacy manifests. |
| `Window`, `Application` | The main window and its toolbar, the menu bar and the app delegate. |

View controllers follow their models with `withObservationTracking` (see `Support/ObservationLoop.swift`), so the UI updates whenever the state changes.

## License

FrameGen is available under the MIT license. See [LICENSE](LICENSE).
