# Canonical copy of the Homebrew formula. The live copy lives here in the
# tap repo at akira-toriyama/homebrew-tap as Formula/chord.rb. On each chord
# release, bump `url` / `sha256` (or rely on the chord repo's
# `.github/workflows/update-tap.yml` once that's wired up — see
# packaging/homebrew/ in the chord repo).
class Chord < Formula
  desc "Global keyboard + mouse hotkey daemon for macOS"
  homepage "https://github.com/akira-toriyama/chord"
  url "https://github.com/akira-toriyama/chord/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "83c45e13457d845f13249bf2ebb6b5d61eb7a1fde1e636987c8ab2d3d2a2501d"
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

    # Hybrid signing (best-effort cert, loud fallback) — same pattern as
    # facet / stroke. The setup script's `.signing-id` artefact carries
    # the identity name back to us so we can sign with it; an absent or
    # failed setup falls back to ad-hoc with a loud warning so the user
    # discovers it before macOS re-prompts on every upgrade.
    sign_id = "-"
    if quiet_system "./setup-signing-cert.sh"
      id_file = ".signing-id"
      sign_id = File.read(id_file).strip if File.exist?(id_file)
    end
    system "codesign", "--force", "--sign", sign_id, app

    if sign_id == "-"
      opoo <<~EOS
        Could not set up a stable self-signed identity in the login
        keychain — signed Chord.app ad-hoc. The app works fine, but every
        `brew upgrade chord` produces a new code hash, so macOS will
        re-prompt for Accessibility on every upgrade.

        To make grants persist across upgrades, run once after install:
          #{opt_pkgshare}/setup-signing-cert.sh
          brew reinstall chord

        Verify:
          codesign -dvv #{opt_prefix}/Chord.app
          # expect: Authority="chord-dev"
      EOS
    else
      ohai "Signed Chord.app with stable self-signed identity " \
           "(\"#{sign_id}\") — TCC grants persist across upgrades."
    end

    # Same binary doubles as the thin CLI client (--reload / --quit /
    # --pause / --resume / --toggle / --validate / --doctor / --status).
    bin.install_symlink app/"Contents/MacOS/chord" => "chord"
  end

  service do
    run [opt_bin/"chord"]
    keep_alive true
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

      Persistent Accessibility grants across `brew upgrade` need a stable
      code-signing identity. The install creates one automatically when
      it can; if the install printed a "fell back to ad-hoc" warning (or
      `codesign -dvv #{opt_prefix}/Chord.app` shows no Authority line),
      run once:
        #{opt_pkgshare}/setup-signing-cert.sh
        brew reinstall chord
    EOS
  end

  test do
    assert_path_exists prefix/"Chord.app/Contents/MacOS/chord"
    # --version + --validate touch no event tap / AX — safe in the brew
    # test sandbox.
    assert_match "chord", shell_output("#{bin}/chord --version")
  end
end
