cask "hyprnote" do
  version "1.0.0-nightly.21"
  sha256 "701fa1f55d4c6110b1c7365c6c5671afab97b007ceddb651520ad304d5215e8f"

  url "https://github.com/fastrepl/hyprnote/releases/download/desktop_v#{version}/hyprnote-macos-aarch64.dmg"
  name "Hyprnote"
  desc "AI-powered note-taking app"
  homepage "https://github.com/fastrepl/hyprnote"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Hyprnote Nightly.app"
end
