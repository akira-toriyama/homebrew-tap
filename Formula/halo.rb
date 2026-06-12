class Halo < Formula
  desc "Neon ring around the active window on macOS — drag-follow + focus flash"
  homepage "https://github.com/akira-toriyama/halo"
  # `url` / `sha256` are bumped automatically by the halo repo's
  # `.github/workflows/update-tap.yml` on every Published release. These
  # placeholders just give the auto-bump's sed something to rewrite; the
  # first published release fills in the real v1.x.y tag + tarball
  # sha256. Until then, install from main with `brew install --HEAD halo`.
  url "https://github.com/akira-toriyama/halo/archive/refs/tags/v2.0.0.tar.gz"
  sha256 "031e0c9f00ddcee36d087e8ed360ee8efd98d02c673e6a45f10e24e6cdfdf613"
  license "MIT"
  head "https://github.com/akira-toriyama/halo.git", branch: "main"

  # swift-tools-version 6.0 requires a Swift 6 toolchain. Builds with
  # the Xcode CLT swift just as well as a full Xcode.app — no full
  # IDE required at install time. macOS 13 (Ventura) is the floor.
  depends_on macos: :ventura

  def install
    # No external SwiftPM deps; --disable-sandbox lets swiftpm write
    # its cache under brew's restricted home.
    system "swift", "build", "--disable-sandbox", "-c", "release"

    app = prefix/"Halo.app"
    (app/"Contents/MacOS").mkpath
    cp "Info.plist", app/"Contents/Info.plist"
    cp ".build/release/halo", app/"Contents/MacOS/halo"

    # Ship the committed icon if present (Info.plist points
    # CFBundleIconFile = AppIcon at it).
    if File.exist?("AppIcon.icns")
      (app/"Contents/Resources").mkpath
      cp "AppIcon.icns", app/"Contents/Resources/AppIcon.icns"
    end

    # Ad-hoc signing is enough: halo touches no TCC-gated APIs (no
    # Accessibility, no Screen Recording — read-only private SkyLight
    # only), so there's no grant to keep stable across upgrades and thus
    # no self-signed-cert dance (unlike facet / perch).
    system "codesign", "--force", "--sign", "-", app
  end

  def caveats
    <<~EOS
      halo draws a neon ring around your active window. It's a GUI agent
      (LSUIElement, no Dock icon, never steals focus). The ring needs no
      permissions; the optional focus-shake (on by default) moves the
      focused window via Accessibility.

      Grant halo Accessibility for focus-shake (System Settings → Privacy
      & Security → Accessibility), or set `shake = false` in config.toml
      to keep halo permission-free. Homebrew installs are ad-hoc signed,
      so re-grant after each `brew upgrade halo`.

      Launch:
        open #{opt_prefix}/Halo.app

      Drop in a config (optional — sensible defaults otherwise):
        curl --create-dirs -o ~/.config/halo/config.toml \\
          https://raw.githubusercontent.com/akira-toriyama/halo/main/config.toml

      Auto-start on login (optional):
        Add #{opt_prefix}/Halo.app to System Settings → General → Login Items.
    EOS
  end

  test do
    assert_path_exists prefix/"Halo.app/Contents/MacOS/halo"
  end
end
