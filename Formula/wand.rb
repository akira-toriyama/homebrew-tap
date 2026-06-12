# Canonical copy of the Homebrew formula. The live copy lives in the tap repo
# at akira-toriyama/homebrew-tap as Formula/wand.rb. Keep this in sync and
# bump `url` / `sha256` on every release tag (see packaging/homebrew/README.md).
#
# The release.yml workflow's `update-tap` job does the bump automatically when
# a draft release is Published — this file is the manual-edit reference, not
# what brew actually reads.
class Wand < Formula
  desc "macOS daemon for cursor-anchored mouse automation — gesture + launcher"
  homepage "https://github.com/akira-toriyama/wand"
  url "https://github.com/akira-toriyama/wand/archive/refs/tags/v8.0.0.tar.gz"
  sha256 "bb1e5cb3812c3e78b55f2385bb115039c7f14d72d0e47c2680e76be4ed91e0c7"
  license "MIT"
  head "https://github.com/akira-toriyama/wand.git", branch: "main"

  # Builds with the Swift toolchain from Xcode *or* the Command Line Tools;
  # a full Xcode.app is not required. swift-tools-version 6.0 needs a Swift 6
  # toolchain — older toolchains fail fast with a clear version error.
  depends_on macos: :ventura

  def install
    # No external SwiftPM deps; --disable-sandbox lets swiftpm write its cache.
    system "swift", "build", "--disable-sandbox", "-c", "release"

    app = prefix/"Wand.app"
    (app/"Contents/MacOS").mkpath
    cp "Info.plist", app/"Contents/Info.plist"
    cp ".build/release/wand", app/"Contents/MacOS/wand"

    # Ship the signing helper under share/ so users can recover the
    # persistent-TCC path later via `brew reinstall`, without needing to
    # clone the source repo.
    pkgshare.install "setup-signing-cert.sh"
    chmod 0755, pkgshare/"setup-signing-cert.sh"

    # Ad-hoc sign the bundle. We intentionally don't try to set up
    # the persistent "wand Local Signing" identity here —
    # Homebrew's build sandbox blocks `security` from touching the
    # user's login keychain, so any attempt would fail silently and
    # fall back to ad-hoc anyway (verified via brew source spelunk +
    # install-log inspection during chord's 0.3.3 work). The user
    # runs `wand --resign` once after install / upgrade to swap in
    # the stable identity — same pattern as chord.
    system "codesign", "--force", "--sign", "-", app

    # Same binary doubles as the thin CLI client (--reload / --quit /
    # --resign / etc).
    bin.install_symlink app/"Contents/MacOS/wand" => "wand"
  end

  def caveats
    <<~EOS
      wand is a macOS daemon for cursor-anchored mouse automation
      (LSUIElement, no Dock icon). Two trigger families share one daemon:

        - gesture (mouse button + drag → recognise a LURD shape → fire)
        - launcher (middle-click → contextual NSMenu, opt-in)

      Both act on the window UNDER the cursor — not the focused one —
      so actions land where you're pointing even on multi-display setups.

      ── One-time signing setup (preserves Accessibility across upgrades) ──

      Homebrew's build sandbox can't touch your login keychain, so
      `brew install` / `brew upgrade wand` produces an ad-hoc-signed
      Wand.app — macOS would otherwise re-prompt for Accessibility
      every upgrade. Run these ONCE on first install:

        #{opt_pkgshare}/setup-signing-cert.sh   # creates "wand Local Signing"
        wand --resign                            # re-signs + restart

      After every subsequent `brew upgrade wand`, just run:

        wand --resign

      Verify the persistent identity took:

        codesign -dvv #{opt_prefix}/Wand.app
        # expect: Authority="wand Local Signing"

      ── First-run setup ──

      First-run setup:
        1) Drop the config template:
             curl --create-dirs -o ~/.config/wand/config.toml \\
               https://raw.githubusercontent.com/akira-toriyama/wand/main/config.toml
        2) Launch the daemon once so macOS shows the AX prompt:
             open #{opt_prefix}/Wand.app
        3) Grant Accessibility to "wand" (System Settings → Privacy &
           Security → Accessibility), then relaunch with `wand`.

      CLI (no daemon needed for these):
        wand --validate    parse config.toml
        wand --record      interactive recorder — draw, see the pattern
        wand --help        all flags

      Client commands (talk to the running daemon over DNC):
        wand --reload      re-read config.toml live
        wand --quit        terminate the running daemon
        wand --show-menu   external-trigger entry to the launcher menu
                           (for `eventfx` text-selection observers etc.)

      Auto-start on login (optional):
        Add #{opt_prefix}/Wand.app to System Settings → General → Login Items.

      ── Migrating from `stroke` (pre-v3.0) ──

        mkdir -p ~/.config/wand && \\
          mv ~/.config/stroke/config.toml ~/.config/wand/  2>/dev/null
        brew uninstall stroke 2>/dev/null
        # Re-grant Accessibility — Wand.app is a new bundle id to TCC.
    EOS
  end

  test do
    assert_path_exists prefix/"Wand.app/Contents/MacOS/wand"
    # --validate touches no event tap / AX — safe in the test sandbox.
    system bin/"wand", "--validate"
  end
end
