# Canonical copy of the Homebrew formula. The live copy lives in the tap repo
# at akira-toriyama/homebrew-tap as Formula/ws-tabs.rb. Keep this in sync and
# bump `url`/`sha256` on every release tag (see packaging/homebrew/README.md).
class WsTabs < Formula
  desc "Translucent workspace + window tab panel for the rift window manager"
  homepage "https://github.com/akira-toriyama/ws-tabs"
  # Reference copy. The REAL sha256 lives only in the tap's Formula/ws-tabs.rb
  # (a sha cannot self-reference the tarball that contains it). Per-release
  # steps: packaging/homebrew/README.md.
  url "https://github.com/akira-toriyama/ws-tabs/archive/refs/tags/v1.4.0.tar.gz"
  sha256 "344a13d324a0681011103c49c161c4cba0383abc2c364e38cb19c3e793b7fe24"
  license "MIT"
  revision 1
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

    # Sign with a stable per-user self-signed identity (idempotently created
    # by setup-signing-cert.sh in the login keychain). Reused on every
    # reinstall/upgrade → the Accessibility (TCC) grant persists. Falls
    # back to ad-hoc signing if the cert can't be created (e.g. login
    # keychain is locked and can't be unlocked non-interactively).
    sign_id = "-"
    if quiet_system "./setup-signing-cert.sh"
      id_file = ".signing-id"
      sign_id = File.read(id_file).strip if File.exist?(id_file)
    end
    system "codesign", "--force", "--sign", sign_id, app

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
        ws-tabs --show | --hide | --toggle | --active | --quit
        ws-tabs --theme="terminal" | "cute" | "system"

      Accessibility persists across `brew upgrade`: the install creates a
      stable per-user self-signed code-signing identity in your login
      keychain (`setup-signing-cert.sh` is idempotent — runs once). On
      first install macOS may prompt to allow keychain access; if your
      login keychain is locked at that moment, install falls back to
      ad-hoc and the grant won't persist.
    EOS
  end

  test do
    assert_path_exists prefix/"WsTabs.app/Contents/MacOS/ws-tabs"
  end
end
