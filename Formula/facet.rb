class Facet < Formula
  desc "Workspace + window manager for macOS — tree sidebar & TS3-style grid"
  homepage "https://github.com/akira-toriyama/facet"
  # `url` / `sha256` are bumped automatically by the facet repo's
  # `.github/workflows/update-tap.yml` on every Published release.
  # Placeholder values here are good for the first run; the first
  # bump rewrites them to the real v1.x.y tag + tarball sha256.
  url "https://github.com/akira-toriyama/facet/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "a8a365203bca77e9c60f1d0a3d7c7dd313b0fbf876f50fe9ac97b8a4be8db6d3"
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

    # Ad-hoc sign the bundle. We intentionally don't try to set up
    # the persistent "facet Local Signing" identity here —
    # Homebrew's build sandbox blocks `security` from touching the
    # user's login keychain, so any attempt would fail silently and
    # fall back to ad-hoc anyway (verified during chord's 0.3.3
    # investigation). The user runs `facet --resign` once after
    # install / upgrade to swap in the stable identity — same
    # pattern as chord and stroke.
    system "codesign", "--force", "--sign", "-", app

    # Same binary doubles as the thin CLI client (--view=* /
    # --theme / --resign / etc).
    bin.install_symlink app/"Contents/MacOS/facet" => "facet"
  end

  def caveats
    <<~EOS
      facet is a GUI agent (LSUIElement) — workspace + window
      manager using only public macOS Accessibility APIs.

      ── One-time signing setup (preserves Accessibility + Screen
         Recording grants across upgrades) ──

      Homebrew's build sandbox can't touch your login keychain, so
      `brew install`/`brew upgrade facet` produces an ad-hoc-signed
      Facet.app — macOS would otherwise re-prompt for Accessibility
      + Screen Recording every upgrade. Run these ONCE on first
      install:

        #{opt_pkgshare}/setup-signing-cert.sh   # "facet Local Signing"
        facet --resign                           # re-signs + restart

      After every subsequent `brew upgrade facet`, just run:

        facet --resign

      Verify the persistent identity took:

        codesign -dvv #{opt_prefix}/Facet.app
        # expect: Authority="facet Local Signing"

      ── First-run setup ──

      Launch the panel:
        open #{opt_prefix}/Facet.app

      Grant Accessibility to "facet" on first launch (System Settings →
      Privacy & Security → Accessibility) or clicks/drags will not
      work. Grant Screen Recording too if you want grid-view
      thumbnails.

      Drop in a config:
        curl --create-dirs -o ~/.config/facet/config.toml \\
          https://raw.githubusercontent.com/akira-toriyama/facet/main/config.toml

      CLI (no GUI / Accessibility needed):
        facet --view=tree | --view=grid | --hide=NAME | --toggle=NAME
        facet --theme="terminal" | "cute" | "system"
        facet --help
    EOS
  end

  test do
    assert_path_exists prefix/"Facet.app/Contents/MacOS/facet"
  end
end
