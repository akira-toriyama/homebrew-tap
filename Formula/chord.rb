# Canonical copy of the Homebrew formula. The live copy lives here in the
# tap repo at akira-toriyama/homebrew-tap as Formula/chord.rb. On each chord
# release, bump `url` / `sha256` (or rely on the chord repo's
# `.github/workflows/update-tap.yml` once that's wired up — see
# packaging/homebrew/ in the chord repo).
class Chord < Formula
  desc "Global keyboard + mouse hotkey daemon for macOS"
  homepage "https://github.com/akira-toriyama/chord"
  url "https://github.com/akira-toriyama/chord/archive/refs/tags/v0.9.0.tar.gz"
  sha256 "11fd8d31f6d2ad1c2becc83f82408857262b7b8148df60c8cf877277b6cbc2b4"
  license "MIT"
  head "https://github.com/akira-toriyama/chord.git", branch: "main"

  # Builds with the Swift toolchain from Xcode *or* the Command Line Tools;
  # a full Xcode.app is not required. swift-tools-version 6.0 needs a Swift 6
  # toolchain — older toolchains fail fast with a clear version error.
  depends_on macos: :ventura

  def install
    # No external SwiftPM deps; --disable-sandbox lets swiftpm write its
    # cache under brew's restricted home.
    system "swift", "build", "--disable-sandbox", "-c", "release"

    app = prefix/"Chord.app"
    (app/"Contents/MacOS").mkpath
    (app/"Contents/Resources").mkpath
    cp "Info.plist", app/"Contents/Info.plist"
    cp ".build/release/chord", app/"Contents/MacOS/chord"
    # Bake the icon in if the repo shipped it (assets/icon/chord.icns is
    # committed; older snapshots without one still install cleanly).
    icns = "assets/icon/chord.icns"
    cp icns, app/"Contents/Resources/AppIcon.icns" if File.exist?(icns)

    # Ship the signing helper + the default config + LaunchAgent template
    # under share/ so users can recover the persistent-TCC path and the
    # auto-start workflow later via `brew reinstall`, without needing to
    # clone the source repo.
    pkgshare.install "setup-signing-cert.sh"
    pkgshare.install "config.toml"
    pkgshare.install(
      "packaging/launchd/com.chord.chord.plist.in" => "launchagent.plist.in",
    )
    chmod 0755, pkgshare/"setup-signing-cert.sh"

    # Ad-hoc sign the bundle. We intentionally don't try to set up
    # the persistent `chord-dev` identity here — Homebrew's build
    # sandbox blocks `security` from touching the user's login
    # keychain, so any attempt would fail silently and fall back to
    # ad-hoc anyway. The user runs `chord --resign` once after
    # install / upgrade to swap in the stable identity (when the
    # binary doubles as a CLI tool with full keychain access via the
    # user's interactive shell, not brew's sandbox).
    system "codesign", "--force", "--sign", "-", app

    # Same binary doubles as the thin CLI client (--reload / --quit /
    # --pause / --resume / --toggle / --validate / --doctor /
    # --status / --resign).
    bin.install_symlink app/"Contents/MacOS/chord" => "chord"
  end

  service do
    run [opt_bin/"chord"]
    # Restart only on SUCCESSFUL exit, NOT on every crash. chord
    # exits 1 when Accessibility is not yet granted (so the user
    # sees `Permissions.promptForAccessibility()` once), and a plain
    # `keep_alive true` turns that into an infinite respawn loop —
    # macOS shows the AX prompt over and over until the user grants
    # it. The `successful_exit` form (equivalent to
    # `KeepAlive = { SuccessfulExit = true }` in launchd) breaks
    # that loop while still restarting after a deliberate
    # `chord --quit` or natural shutdown.
    keep_alive successful_exit: true
    log_path var/"log/chord.log"
    error_log_path var/"log/chord.log"
    # Homebrew's default PATH is bare — Add Homebrew + system PATH so any
    # `action-shell = "..."` calling brew-installed tools (yabai, fzf, …)
    # actually finds them. Mirrors the LaunchAgent template chord ships.
    environment_variables PATH: "/opt/homebrew/bin:/opt/homebrew/sbin:" \
                                "/usr/local/bin:/usr/bin:/bin:" \
                                "/usr/sbin:/sbin"
  end

  def caveats
    <<~EOS
      chord is a global keyboard + mouse hotkey daemon (LSUIElement, no
      Dock icon). It taps every key + button event the OS produces, so it
      needs the Accessibility grant once.

      ── One-time signing setup (preserves Accessibility across upgrades) ──

      Homebrew's build sandbox can't touch your login keychain, so
      `brew install`/`brew upgrade chord` produces an ad-hoc-signed
      Chord.app — macOS would otherwise re-prompt for Accessibility
      every upgrade. Run these ONCE on first install:

        #{opt_pkgshare}/setup-signing-cert.sh   # creates 'chord-dev' identity
        chord --resign                            # re-signs Chord.app + restart

      After every subsequent `brew upgrade chord`, just run:

        chord --resign

      Verify the persistent identity took:

        codesign -dvv #{opt_prefix}/Chord.app
        # expect: Authority=chord-dev

      ── First-run setup ──

      First-run setup:
        1) Drop the config template (shipped template is all-commented,
           pick patterns to uncomment):
             cp #{opt_pkgshare}/config.toml ~/.config/chord/config.toml
             $EDITOR ~/.config/chord/config.toml
        2) Launch the daemon once so macOS shows the AX prompt:
             open #{opt_prefix}/Chord.app
        3) Grant Accessibility to "chord" (System Settings → Privacy &
           Security → Accessibility), then relaunch with `chord`.
        4) (Optional) auto-start on login via Homebrew services:
             brew services start chord

      CLI (no daemon needed for these):
        chord --validate              parse config.toml
        chord --validate --strict     CI mode — warnings + drops exit 1
        chord --doctor                report AX / config / daemon liveness
        chord --help                  all flags

      Client commands (talk to the running daemon over DNC):
        chord --reload                re-read config.toml live
        chord --pause / --resume      suspend / resume all bindings
        chord --toggle                flip paused ↔ resumed (handy hotkey)
        chord --status                show last status line
        chord --quit                  terminate the running daemon

    EOS
  end

  test do
    assert_path_exists prefix/"Chord.app/Contents/MacOS/chord"
    # --version + --validate touch no event tap / AX — safe in the brew
    # test sandbox.
    assert_match "chord", shell_output("#{bin}/chord --version")
  end
end
