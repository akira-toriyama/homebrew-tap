# Canonical copy of the Homebrew formula. The live copy lives in the tap repo
# at akira-toriyama/homebrew-tap as Formula/ws-tabs.rb. Keep this in sync and
# bump `url`/`sha256` on every release tag (see packaging/homebrew/README.md).
class WsTabs < Formula
  desc "Translucent workspace + window tab panel for the rift window manager"
  homepage "https://github.com/akira-toriyama/ws-tabs"
  # After `git tag v1.0 && git push --tags`, set sha256 (see runbook).
  url "https://github.com/akira-toriyama/ws-tabs/archive/refs/tags/v1.0.tar.gz"
  sha256 "f39ba00270f0fad8308865747600aa3cdeebaf2bf2d72bfd990ddf20daf3db5d"
  license "MIT"
  head "https://github.com/akira-toriyama/ws-tabs.git", branch: "main"

  depends_on xcode: :build
  depends_on macos: :ventura

  def install
    # No external SwiftPM deps; --disable-sandbox lets swiftpm write its cache.
    system "swift", "build", "--disable-sandbox", "-c", "release"

    app = prefix/"WsTabs.app"
    (app/"Contents/MacOS").mkpath
    cp "Info.plist", app/"Contents/Info.plist"
    # SwiftPM target is still `rift-tabs`; shipped executable is `ws-tabs`.
    cp ".build/release/rift-tabs", app/"Contents/MacOS/ws-tabs"
    # Ad-hoc sign: fine for a Homebrew install. The durable self-signed-cert
    # trick (setup-signing-cert.sh) is only for keeping the TCC grant across
    # local rebuilds when developing from source.
    system "codesign", "--force", "--sign", "-", app

    # Same binary doubles as the thin CLI client (--show/--hide/--theme).
    bin.install_symlink app/"Contents/MacOS/ws-tabs" => "ws-tabs"
  end

  def caveats
    <<~EOS
      ws-tabs is a GUI agent (LSUIElement) that drives the rift window manager.

      Launch the panel:
        open #{opt_prefix}/WsTabs.app

      Grant Accessibility to "ws-tabs" on first launch (System Settings →
      Privacy & Security → Accessibility) or clicks/drags will not work.

      Requires rift + rift-cli on PATH:
        https://github.com/acsandmann/rift

      CLI (no GUI / Accessibility needed):
        ws-tabs --show | --hide | --toggle
        ws-tabs --theme="terminal" | "cute" | "system"

      Homebrew ad-hoc signs the app, so a reinstall/upgrade re-prompts for
      Accessibility. Build from source with setup-signing-cert.sh for a
      durable grant.
    EOS
  end

  test do
    assert_path_exists prefix/"WsTabs.app/Contents/MacOS/ws-tabs"
  end
end
