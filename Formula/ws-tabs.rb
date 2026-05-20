# Canonical copy of the Homebrew formula. The live copy lives in the tap repo
# at akira-toriyama/homebrew-tap as Formula/ws-tabs.rb. Keep this in sync and
# bump `url`/`sha256` on every release tag (see packaging/homebrew/README.md).
class WsTabs < Formula
  desc "Translucent workspace + window tab panel for the rift window manager"
  homepage "https://github.com/akira-toriyama/ws-tabs"
  # Reference copy. The REAL sha256 lives only in the tap's Formula/ws-tabs.rb
  # (a sha cannot self-reference the tarball that contains it). Per-release
  # steps: packaging/homebrew/README.md.
  url "https://github.com/akira-toriyama/ws-tabs/archive/refs/tags/v1.5.0.tar.gz"
  sha256 "0f6aef7b50018792e830daf04a4c9a0077323af40e40e41701f5ca49a63b9f0d"
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

    # Ship the signing helper under share/ so users can recover the
    # persistent-TCC path later via `brew reinstall`, without needing to
    # clone the source repo.
    pkgshare.install "setup-signing-cert.sh"
    chmod 0755, pkgshare/"setup-signing-cert.sh"

    # Hybrid signing (best-effort cert, loud fallback):
    # 1. Try to set up / reuse a stable per-user self-signed identity in
    #    the login keychain. When this works, the code-signing leaf hash
    #    stays constant across reinstalls, so TCC grants (Accessibility +
    #    Screen Recording) persist across `brew upgrade`.
    # 2. If the script fails — locked login keychain, brew sandbox
    #    quirks, missing openssl, etc. — fall back to ad-hoc signing
    #    (always works) and emit a LOUD warning with a copy-pasteable
    #    recovery path. Without the warning the fallback is silent and
    #    users only notice when macOS re-prompts on every upgrade.
    sign_id = "-"
    if quiet_system "./setup-signing-cert.sh"
      id_file = ".signing-id"
      sign_id = File.read(id_file).strip if File.exist?(id_file)
    end
    system "codesign", "--force", "--sign", sign_id, app

    if sign_id == "-"
      opoo <<~EOS
        Could not set up a stable self-signed identity in the login keychain —
        signed WsTabs.app ad-hoc. The app works fine, but every
        `brew upgrade ws-tabs` produces a new code hash, so macOS will
        re-prompt for Accessibility + Screen Recording on every upgrade.

        To make grants persist across upgrades, run once after install:
          #{opt_pkgshare}/setup-signing-cert.sh
          brew reinstall ws-tabs

        Verify:
          codesign -dvv #{opt_prefix}/WsTabs.app
          # expect: Authority="rift-tabs Local Signing"
      EOS
    else
      ohai "Signed WsTabs.app with stable self-signed identity " \
           "(\"#{sign_id}\") — TCC grants persist across upgrades."
    end

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

      Persistent Accessibility / Screen Recording grants across
      `brew upgrade` need a stable code-signing identity. The install
      creates one automatically when it can; if the install printed a
      "fell back to ad-hoc" warning (or `codesign -dvv
      #{opt_prefix}/WsTabs.app` shows no Authority line), run once:
        #{opt_pkgshare}/setup-signing-cert.sh
        brew reinstall ws-tabs
    EOS
  end

  test do
    assert_path_exists prefix/"WsTabs.app/Contents/MacOS/ws-tabs"
  end
end
