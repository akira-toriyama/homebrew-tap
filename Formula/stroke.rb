# Canonical copy of the Homebrew formula. The live copy lives in the tap repo
# at akira-toriyama/homebrew-tap as Formula/stroke.rb. Keep this in sync and
# bump `url` / `sha256` on every release tag (see packaging/homebrew/README.md).
#
# The release.yml workflow's `update-tap` job does the bump automatically when
# a draft release is Published — this file is the manual-edit reference, not
# what brew actually reads.
class Stroke < Formula
  desc "Global mouse-gesture daemon for macOS — acts on the window under the cursor"
  homepage "https://github.com/akira-toriyama/stroke"
  # Reference copy. The REAL sha256 lives only in the tap's Formula/stroke.rb
  # (a sha cannot self-reference the tarball that contains it). Per-release
  # steps: packaging/homebrew/README.md.
  url "https://github.com/akira-toriyama/stroke/archive/refs/tags/v2.3.0.tar.gz"
  sha256 "191f025a6e7915f6510f6584fd193ad99fd56c0b69c9786aeb580a1860c76eac"
  license "MIT"
  head "https://github.com/akira-toriyama/stroke.git", branch: "main"

  # Builds with the Swift toolchain from Xcode *or* the Command Line Tools;
  # a full Xcode.app is not required. swift-tools-version 6.0 needs a Swift 6
  # toolchain — older toolchains fail fast with a clear version error.
  depends_on macos: :ventura

  def install
    # No external SwiftPM deps; --disable-sandbox lets swiftpm write its cache.
    system "swift", "build", "--disable-sandbox", "-c", "release"

    app = prefix/"Stroke.app"
    (app/"Contents/MacOS").mkpath
    cp "Info.plist", app/"Contents/Info.plist"
    cp ".build/release/stroke", app/"Contents/MacOS/stroke"

    # Ship the signing helper under share/ so users can recover the
    # persistent-TCC path later via `brew reinstall`, without needing to
    # clone the source repo.
    pkgshare.install "setup-signing-cert.sh"
    chmod 0755, pkgshare/"setup-signing-cert.sh"

    # Ad-hoc sign the bundle. We intentionally don't try to set up
    # the persistent "stroke Local Signing" identity here —
    # Homebrew's build sandbox blocks `security` from touching the
    # user's login keychain, so any attempt would fail silently and
    # fall back to ad-hoc anyway (verified via brew source spelunk +
    # install-log inspection during chord's 0.3.3 work). The user
    # runs `stroke --resign` once after install / upgrade to swap in
    # the stable identity — same pattern as chord.
    system "codesign", "--force", "--sign", "-", app

    # Same binary doubles as the thin CLI client (--reload / --quit /
    # --resign / etc).
    bin.install_symlink app/"Contents/MacOS/stroke" => "stroke"
  end

  def caveats
    <<~EOS
      stroke is a global mouse-gesture daemon (LSUIElement, no Dock icon).
      It acts on the window UNDER the cursor — not the focused one — so
      gestures land where you're pointing even on multi-display setups.

      ── One-time signing setup (preserves Accessibility across upgrades) ──

      Homebrew's build sandbox can't touch your login keychain, so
      `brew install`/`brew upgrade stroke` produces an ad-hoc-signed
      Stroke.app — macOS would otherwise re-prompt for Accessibility
      every upgrade. Run these ONCE on first install:

        #{opt_pkgshare}/setup-signing-cert.sh   # creates "stroke Local Signing"
        stroke --resign                          # re-signs + restart

      After every subsequent `brew upgrade stroke`, just run:

        stroke --resign

      Verify the persistent identity took:

        codesign -dvv #{opt_prefix}/Stroke.app
        # expect: Authority="stroke Local Signing"

      ── First-run setup ──

      First-run setup:
        1) Drop the config template:
             curl --create-dirs -o ~/.config/stroke/config.toml \\
               https://raw.githubusercontent.com/akira-toriyama/stroke/main/config.toml
        2) Launch the daemon once so macOS shows the AX prompt:
             open #{opt_prefix}/Stroke.app
        3) Grant Accessibility to "stroke" (System Settings → Privacy &
           Security → Accessibility), then relaunch with `stroke`.

      CLI (no daemon needed for these):
        stroke --validate    parse config.toml
        stroke --record      interactive recorder — draw, see the pattern
        stroke --help        all flags

      Client commands (talk to the running daemon over DNC):
        stroke --reload      re-read config.toml live
        stroke --quit        terminate the running daemon

      Auto-start on login (optional):
        Add #{opt_prefix}/Stroke.app to System Settings → General → Login Items.
    EOS
  end

  test do
    assert_path_exists prefix/"Stroke.app/Contents/MacOS/stroke"
    # --validate touches no event tap / AX — safe in the test sandbox.
    system bin/"stroke", "--validate"
  end
end
