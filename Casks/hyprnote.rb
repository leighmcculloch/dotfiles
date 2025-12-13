cask "hyprnote" do
  version "1.0.0-nightly.17"
  sha256 "4b66fbe1879a488e206c1c1bb3356a57d3a8ea93de50216efdf0c11b1a75754f"

  url "https://github.com/fastrepl/hyprnote/releases/download/desktop_v#{version}/hyprnote-macos-aarch64.dmg"
  name "Hyprnote"
  desc "AI-powered note-taking app"
  homepage "https://github.com/fastrepl/hyprnote"

  depends_on macos: ">= :sonoma"
  depends_on arch: :arm64

  app "Hyprnote Nightly.app"
end
