cask "framegen" do
  # scripts/update-cask.sh fills in version and sha256 on release.
  version "2.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/Ramiz69/FrameGen/releases/download/v#{version}/FrameGen-#{version}.zip"
  name "FrameGen"
  desc "Builds XCFrameworks and SwiftPM binary targets from Xcode framework projects"
  homepage "https://github.com/Ramiz69/FrameGen"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :arm64
  depends_on macos: ">= :golden_gate"

  app "FrameGen.app"
  binary "#{appdir}/FrameGen.app/Contents/Helpers/framegen"

  zap trash: [
    "~/Library/Preferences/ru.ramiz-kichibekov.frameGen.plist",
    "~/Library/Saved Application State/ru.ramiz-kichibekov.frameGen.savedState",
  ]
end
