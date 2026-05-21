class Facet < Formula
  desc "Workspace + window manager for macOS — tree sidebar & TS3-style grid"
  homepage "https://github.com/akira-toriyama/facet"
  # `url` / `sha256` are bumped automatically by the facet repo's
  # `.github/workflows/update-tap.yml` on every Published release.
  # Placeholder values here are good for the first run; the first
  # bump rewrites them to the real v1.x.y tag + tarball sha256.
  url "https://github.com/akira-toriyama/facet/archive/refs/tags/v0.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/akira-toriyama/facet.git", branch: "main"

  # swift-tools-version 6.0 requires a Swift 6 toolchain. Builds with
  # the Xcode CLT swift just as well as a full Xcode.app — no full
  # IDE required at install time. macOS 13 (Ventura) is the floor.
  depends_on macos: :ventura

  def install
    # No external SwiftPM deps; --disable-sandbox lets swiftpm write
    # its cache under brew's restricted home.
    system "swift", "build", "--disable-sandbox", "-c", "release"

    app = prefix/"Facet.app"
    (app/"Contents/MacOS").mkpath
    cp "Info.plist", app/"Contents/Info.plist"
    cp ".build/release/facet", app/"Contents/MacOS/facet"

    # Ship the signing helper under share/ so users can recover the
    # persistent-TCC path later via `brew reinstall`, without needing
    # the source repo.
    pkgshare.install "setup-signing-cert.sh"
    chmod 0755, pkgshare/"setup-signing-cert.sh"

    # Hybrid signing (best-effort cert, loud fallback):
    # 1. Try to set up / reuse a stable per-user self-signed identity
    #    in the login keychain. When this works, the code-signing leaf
    #    hash stays constant across reinstalls, so TCC grants
    #    (Accessibility + Screen Recording) persist across
    #    `brew upgrade`.
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
        Could not set up a stable self-signed identity in the login
        keychain — signed Facet.app ad-hoc. The app works fine, but
        every `brew upgrade facet` produces a new code hash, so macOS
        will re-prompt for Accessibility + Screen Recording on every
        upgrade.

        To make grants persist across upgrades, run once after install:
          #{opt_pkgshare}/setup-signing-cert.sh
          brew reinstall facet

        Verify:
          codesign -dvv #{opt_prefix}/Facet.app
          # expect: Authority="facet Local Signing"
      EOS
    else
      ohai "Signed Facet.app with stable self-signed identity " \
           "(\"#{sign_id}\") — TCC grants persist across upgrades."
    end

    # Same binary doubles as the thin CLI client (--view=*/--theme/...).
    bin.install_symlink app/"Contents/MacOS/facet" => "facet"
  end

  def caveats
    <<~EOS
      facet is a GUI agent (LSUIElement) that drives the rift window
      manager.

      Launch the panel:
        open #{opt_prefix}/Facet.app

      Grant Accessibility to "facet" on first launch (System Settings →
      Privacy & Security → Accessibility) or clicks/drags will not
      work. Grant Screen Recording too if you want grid-view
      thumbnails.

      Drop in a config:
        curl --create-dirs -o ~/.config/facet/config.toml \\
          https://raw.githubusercontent.com/akira-toriyama/facet/main/config.toml

      Requires rift + rift-cli on PATH:
        https://github.com/acsandmann/rift

      CLI (no GUI / Accessibility needed):
        facet --view=tree | --view=grid | --hide=NAME | --toggle=NAME
        facet --theme="terminal" | "cute" | "system"
        facet --help

      Persistent Accessibility / Screen Recording grants across
      `brew upgrade` need a stable code-signing identity. The install
      creates one automatically when it can; if the install printed a
      "fell back to ad-hoc" warning (or `codesign -dvv
      #{opt_prefix}/Facet.app` shows no Authority line), run once:
        #{opt_pkgshare}/setup-signing-cert.sh
        brew reinstall facet
    EOS
  end

  test do
    assert_path_exists prefix/"Facet.app/Contents/MacOS/facet"
  end
end
