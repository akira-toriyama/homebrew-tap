class Halo < Formula
  desc "Neon ring around the active window on macOS — drag-follow + focus flash"
  homepage "https://github.com/akira-toriyama/halo"
  # `url` / `sha256` are bumped automatically by the halo repo's
  # `.github/workflows/update-tap.yml` on every Published release. These
  # placeholders just give the auto-bump's sed something to rewrite; the
  # first published release fills in the real v1.x.y tag + tarball
  # sha256. Until then, install from main with `brew install --HEAD halo`.
  url "https://github.com/akira-toriyama/halo/archive/refs/tags/v4.0.0.tar.gz"
  sha256 "8fdf7f065914a1e170d372f0ab9b2ddf04b3c0bd8b94312c57e0dcfe2ca46c19"
  license "MIT"
  head "https://github.com/akira-toriyama/halo.git", branch: "main"

  # swift-tools-version 6.0 requires a Swift 6 toolchain. Builds with
  # the Xcode CLT swift just as well as a full Xcode.app — no full
  # IDE required at install time. macOS 26 (Tahoe) is the floor —
  # halo's Package.swift declares `platforms: [.macOS("26.0")]` (the
  # floor sill raised for its SwiftUI migration), so an older host
  # would only fail later inside `swift build`.
  depends_on macos: :tahoe

  def install
    # SwiftPM resolves sill + swift-toml-edit (and their transitive
    # packages) from GitHub; --disable-sandbox lets swiftpm fetch and
    # write its cache under brew's restricted home.
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

    # Ad-hoc signing. The ring is read-only (private SkyLight + a
    # click-through overlay), but focus-shake moves the focused window
    # via Accessibility, and TCC keys that grant to the signing identity
    # — so an ad-hoc-signed upgrade drops it (the caveats say so). The
    # self-signed-cert step halo's package.sh offers is a dev-loop
    # convenience, not something a formula can do.
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
