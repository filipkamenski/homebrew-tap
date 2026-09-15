cask "helium-linux" do
  arch arm: "arm64", intel: "x86_64"

  version "0.17.0.1"
  sha256 arm64_linux:  "4c41e22a5cbe2854bc3bd45aa7a74bce16087f727f8f65ad651c7ba1ab84b46f",
         x86_64_linux: "50238835e8896253d4af142a3032354119c1e6f7e777926c4530195c714ff3f5"

  url "https://github.com/imputnet/helium-linux/releases/download/#{version}/helium-#{version}-#{arch}_linux.tar.xz"
  name "Helium"
  desc "Chromium-based web browser"
  homepage "https://helium.computer/"

  livecheck do
    url "https://github.com/imputnet/helium-linux"
    strategy :github_latest
  end

  binary "helium-#{version}-#{arch}_linux/helium-wrapper", target: "helium"
  artifact "helium-#{version}-#{arch}_linux/product_logo_256.png",
           target: "#{Dir.home}/.local/share/icons/helium.png"
  artifact "helium-#{version}-#{arch}_linux/helium.desktop",
           target: "#{Dir.home}/.local/share/applications/helium.desktop"

  preflight_steps do
    pkg_dir = "#{staged_path}/helium-#{version}-#{arch}_linux"

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons"

    desktop = File.read("#{pkg_dir}/helium.desktop")
    desktop.gsub!(/^Exec=helium(\s|$)/, "Exec=#{HOMEBREW_PREFIX}/bin/helium\\1")
    desktop.gsub!(/^Icon=helium$/, "Icon=#{Dir.home}/.local/share/icons/helium.png")
    File.write("#{pkg_dir}/helium.desktop", desktop)

    FileUtils.chmod 0755, "#{pkg_dir}/helium-wrapper"

    if ENV["HOMEBREW_HELIUM_WIDEVINE"] == "1"
      puts "#{Tty.blue}==> Installing Widevine DRM support...#{Tty.reset}"

      require "tmpdir"

      begin
        chromium_version = nil
        IO.popen(["strings", "#{pkg_dir}/helium"], err: "/dev/null") do |io|
          io.each_line do |line|
            if line =~ /Chrome\/(\d+\.\d+\.\d+\.\d+)/
              chromium_version = Regexp.last_match(1)
              break
            end
          end
        end

        raise "Could not detect Chromium version from helium binary" if chromium_version.nil? || chromium_version.empty?

        chrome_arch = (arch == "x86_64") ? "amd64" : "arm64"
        deb_url = "https://dl.google.com/linux/deb/pool/main/g/google-chrome-stable/google-chrome-stable_#{chromium_version}-1_#{chrome_arch}.deb"

        Dir.mktmpdir("helium-widevine") do |tmpdir|
          deb_path = "#{tmpdir}/chrome.deb"
          raise "Download failed" unless system("curl", "-fsSL", "-o", deb_path, deb_url)

          Dir.chdir(tmpdir) do
            raise "ar extract failed" unless system("ar", "x", "chrome.deb", "data.tar.xz")
          end

          raise "tar extract failed" unless system("tar", "-xf", "#{tmpdir}/data.tar.xz",
            "-C", pkg_dir, "--strip-components=4", "./opt/google/chrome/WidevineCdm/")
        end

        puts "#{Tty.green}==> Widevine DRM installed successfully (#{chromium_version}).#{Tty.reset}"
      rescue => e
        puts "#{Tty.yellow}Warning: Widevine installation failed: #{e.message}#{Tty.reset}"
        puts "#{Tty.yellow}Warning: Premium media (Netflix, Spotify, etc.) won't play.#{Tty.reset}"
        puts "#{Tty.yellow}Warning: Retry with: HOMEBREW_HELIUM_WIDEVINE=1 brew reinstall helium-linux#{Tty.reset}"
      end
    end
  end

  caveats <<~EOS
    If the sandbox fails (user namespaces disabled), launch with:
      helium --no-sandbox
  EOS
end
