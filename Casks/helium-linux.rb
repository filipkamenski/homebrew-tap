cask "helium-linux" do
  arch arm: "arm64", intel: "x86_64"

  version "0.17.2.1"
  sha256 arm64_linux:  "e96629974b88b87f2928f36777313d6aa4f29b8b80d8cc7839fa7ee91786ed1d",
         x86_64_linux: "2a639df54e3d05f413cfbb4622a4d1a68584b31da5a7aaf58ee3cd83c7c3e299"

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

  preflight do
    pkg_dir = "#{staged_path}/helium-#{version}-#{arch}_linux"

    FileUtils.mkdir_p "#{Dir.home}/.local/share/applications"
    FileUtils.mkdir_p "#{Dir.home}/.local/share/icons"

    desktop = File.read("#{pkg_dir}/helium.desktop")
    desktop.gsub!(/^Exec=helium(\s|$)/, "Exec=#{HOMEBREW_PREFIX}/bin/helium\\1")
    desktop.gsub!(/^Icon=helium$/, "Icon=#{Dir.home}/.local/share/icons/helium.png")
    File.write("#{pkg_dir}/helium.desktop", desktop)

    FileUtils.chmod 0755, "#{pkg_dir}/helium-wrapper"

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
    end
  end

  caveats <<~EOS
    If the sandbox fails (user namespaces disabled), launch with:
      helium --no-sandbox
  EOS
end
