# Homebrew formula for eventfx.
# Source: https://github.com/akira-toriyama/eventfx
# Bump url/sha256 on every release tag.
class Eventfx < Formula
  desc "macOS daemon that runs commands on active window change"
  homepage "https://github.com/akira-toriyama/eventfx"
  url "https://github.com/akira-toriyama/eventfx/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "01e0aca74a652f663bb4e7a59a87dc5a74969ec450ef582bbb0dd9c6eac89639"
  license "MIT"
  head "https://github.com/akira-toriyama/eventfx.git", branch: "main"

  # Builds with the Swift toolchain from Xcode or Command Line Tools.
  depends_on macos: :ventura

  def install
    system "./build.sh"
    bin.install "bin/eventfx"
  end

  service do
    run [opt_bin/"eventfx"]
    run_at_load true
    keep_alive true
    process_type :interactive
    log_path var/"log/eventfx.log"
    error_log_path var/"log/eventfx.err.log"
    # launchd 既定 PATH には Homebrew が無いため、config から呼ぶコマンド
    # (borders など) を解決できるよう明示する。
    environment_variables PATH: "/opt/homebrew/bin:/opt/homebrew/sbin:" \
                                "/usr/local/bin:/usr/bin:/bin:" \
                                "/usr/sbin:/sbin"
  end

  def caveats
    <<~EOS
      eventfx is a background daemon. It watches the active (focused) window
      and dispatches commands from your config file:
        ${XDG_CONFIG_HOME:-$HOME/.config}/eventfx/config
      (a sample is auto-generated on first run if the file is missing).

      Start (also auto-runs at login afterward):
        brew services start eventfx

      Grant Accessibility to "eventfx" on first run (System Settings →
      Privacy & Security → Accessibility). Without it, the daemon can still
      detect application switches but cannot resolve the focused window
      inside an app.

      Stop:
        brew services stop eventfx

      Documentation: #{homepage}
    EOS
  end

  test do
    assert_path_exists bin/"eventfx"
  end
end
