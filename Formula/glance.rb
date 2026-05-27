# Canonical copy of the Homebrew formula. The live copy lives here in the
# tap repo at akira-toriyama/homebrew-tap as Formula/glance.rb. On each
# glance release, the glance repo's `.github/workflows/update-tap.yml`
# bumps `url` / `sha256` automatically when HOMEBREW_TAP_TOKEN is set.
class Glance < Formula
  desc "One-shot CLI that shows stdin in a non-activating macOS popover"
  homepage "https://github.com/akira-toriyama/glance"
  url "https://github.com/akira-toriyama/glance/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "bbdca2d4ff8e1c76f0f647e7335701ce5bdc1303f2b110dd8c65e499cfb45f0b"
  license "MIT"
  head "https://github.com/akira-toriyama/glance.git", branch: "main"

  # macOS 13+: depends on `.nonactivatingPanel`, NSAttributedString markdown
  # API, and the presentationIntent lineage. Builds with the Swift toolchain
  # from Xcode *or* the Command Line Tools (full Xcode.app not required).
  depends_on macos: :ventura

  def install
    # SwiftPM deps (swift-markdown / Highlightr) resolve at build time;
    # --disable-sandbox lets swiftpm write its cache under brew's
    # restricted HOME.
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/glance"
  end

  test do
    # --version prints the embedded version (matches the formula `version`).
    assert_match version.to_s, shell_output("#{bin}/glance --version")
  end
end
