# Homebrew Cask template — this file is the source of truth for the cask, but
# it LIVES in the separate tap repo: akira-toriyama/homebrew-tap/Casks/weave.rb
# Copy it there once on first setup; thereafter `.github/workflows/update-tap.yml`
# auto-bumps the version + sha256 there on each published release.
#
# Install:  brew install akira-toriyama/tap/weave
#
# Notes:
# - This app ships UNSIGNED (no Apple Developer ID, no notarization). The
#   `postflight` block strips the quarantine xattr so Gatekeeper allows launch.
# - The same pattern is used by other unsigned Electron casks (e.g.
#   BlueBubbles, Appium Inspector) — see CLAUDE.md References.
cask "weave" do
  arch arm: "arm64", intel: "x64"

  version "0.0.1"
  sha256 arm:   "0000000000000000000000000000000000000000000000000000000000000000",
         intel: "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/akira-toriyama/weave/releases/download/v#{version}/Weave-#{version}-#{arch}.dmg",
      verified: "github.com/akira-toriyama/weave/"
  name "weave"
  desc "Spatial code editor — files on an infinite canvas with import arrows and a native Claude Code agent"
  homepage "https://github.com/akira-toriyama/weave"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :monterey"

  app "Weave.app"

  postflight do
    system "xattr", "-r", "-d", "com.apple.quarantine", "#{appdir}/Weave.app"
  end

  uninstall quit: "com.weave.app"

  zap trash: [
    "~/Library/Application Support/Weave",
    "~/Library/Logs/Weave",
    "~/Library/Preferences/com.weave.app.plist",
    "~/Library/Saved Application State/com.weave.app.savedState",
  ]
end
