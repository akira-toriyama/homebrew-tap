# Canonical copy of the Homebrew formula. The live copy lives in the tap repo
# at akira-toriyama/homebrew-tap as Formula/ws-tabs.rb. Keep this in sync and
# bump `url`/`sha256` on every release tag (see packaging/homebrew/README.md).
class WsTabs < Formula
  desc "Translucent workspace + window tab panel for the rift window manager"
  homepage "https://github.com/akira-toriyama/ws-tabs"
  # Reference copy. The REAL sha256 lives only in the tap's Formula/ws-tabs.rb
  # (a sha cannot self-reference the tarball that contains it). Per-release
  # steps: packaging/homebrew/README.md.
  url "https://github.com/akira-toriyama/ws-tabs/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "dd1c7332430caa211d5c4085acea9c2c0e9b77add63a7526c79d13a0f085788f"
  license "MIT"
  head "https://github.com/akira-toriyama/ws-tabs.git", branch: "main"

  # Builds with the Swift toolchain from Xcode *or* the Command Line Tools;
  # a full Xcode.app is not required. swift-tools-version 6.0 needs a Swift 6
  # toolchain — older toolchains fail fast with a clear version error.
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
