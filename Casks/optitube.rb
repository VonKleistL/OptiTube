cask "optitube" do
  version "0.4.1"
  sha256 "e63d0d61bb6d0c2c5a61db54fd10606a1816b70e822c867588d0a301a5dd49b1"

  url "https://github.com/VonKleistL/OptiTube/releases/download/v#{version}/optitube-v#{version}.dmg"
  name "OptiTube"
  desc "Native YouTube Music client"
  homepage "https://github.com/VonKleistL/OptiTube"

  deprecate! date: "2026-01-06", because: "has moved to the tap at https://github.com/VonKleistL/homebrew-repo"

  auto_updates false
  depends_on macos: ">= :tahoe"

  app "OptiTube.app"

  caveats <<~EOS
      This tap is deprecated and will no longer receive updates.

    To migrate to the new tap:
      brew untap VonKleistL/optitube
      brew install VonKleistL/repo/optitube
  EOS

  postflight do
    system_command "/usr/bin/xattr", args: ["-cr", "#{appdir}/OptiTube.app"], sudo: false
  end

  zap trash: [
    "~/Library/Application Support/OptiTube",
    "~/Library/Caches/com.VonKleistL.OptiTube",
    "~/Library/Preferences/com.VonKleistL.OptiTube.plist",
    "~/Library/Saved Application State/com.VonKleistL.OptiTube.savedState",
    "~/Library/WebKit/com.VonKleistL.OptiTube",
  ]
end
