# Live copy of the jig Homebrew formula (canonical source:
# akira-toriyama/jig packaging/homebrew/jig.rb). On each jig release, the
# jig repo's `.github/workflows/update-tap.yml` bumps `url` / `sha256`
# automatically when HOMEBREW_TAP_TOKEN is set.
#
# NOTE: placeholder url/sha256 until the first release (v0.1.0) is
# published — `brew install` works once update-tap fills in real values.
class Jig < Formula
  desc "Jq-compatible JSON processor with humane errors"
  homepage "https://github.com/akira-toriyama/jig"
  url "https://github.com/akira-toriyama/jig/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/akira-toriyama/jig.git", branch: "main"

  depends_on macos: :ventura

  def install
    system "./build.sh"
    bin.install "bin/jig"
  end

  def caveats
    <<~EOS
      jig runs jq filters with source-span diagnostics and hints:

        curl -s https://api.example.com/users | jig '.[] | .name'

      Compatibility policy and the supported filter subset:
        #{homepage}/blob/main/docs/jq-compat.md
    EOS
  end

  test do
    assert_match(/jig/, shell_output("#{bin}/jig --version"))
    assert_equal "1", pipe_output("#{bin}/jig -c .a", '{"a":1}').strip
  end
end
