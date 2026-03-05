class TuneServer < Formula
  desc "Multi-room audio server with streaming service integration"
  homepage "https://github.com/renesenses/tune-server"
  version "0.1.0"

  on_arm do
    url "https://github.com/renesenses/tune-macos/releases/download/v#{version}/tune-server-#{version}-macos-arm64.tar.gz"
    sha256 "PLACEHOLDER"
  end

  on_intel do
    url "https://github.com/renesenses/tune-macos/releases/download/v#{version}/tune-server-#{version}-macos-x86_64.tar.gz"
    sha256 "f9067df82e98c9c1d9015eb9cabf548632c9e9b6e186b44912ce12ff644245e4"
  end

  depends_on "ffmpeg"
  depends_on :macos

  def install
    # Remove bundled FFmpeg — use Homebrew's
    rm_f "ffmpeg"
    rm_f "ffprobe"
    rm_rf "lib"

    # Install everything under libexec
    libexec.install Dir["*"]

    # Wrapper script
    (bin/"tune-server").write <<~SHELL
      #!/bin/bash
      export TUNE_WEB_DIR="${TUNE_WEB_DIR:-#{libexec}/web}"
      export TUNE_DB_PATH="${TUNE_DB_PATH:-#{var}/tune-server/tune_server.db}"
      export TUNE_ARTWORK_CACHE_DIR="${TUNE_ARTWORK_CACHE_DIR:-#{var}/tune-server/artwork_cache}"
      exec "#{libexec}/tune-server" "$@"
    SHELL

    # Create data directories
    (var/"tune-server").mkpath
    (var/"tune-server/artwork_cache").mkpath
  end

  service do
    run [opt_bin/"tune-server"]
    keep_alive true
    working_dir var/"tune-server"
    log_path var/"log/tune-server.log"
    error_log_path var/"log/tune-server.log"
    environment_variables PATH: std_service_path_env
  end

  def caveats
    <<~EOS
      Data is stored in:
        #{var}/tune-server/

      Start the service:
        brew services start tune-server

      Then open:
        http://localhost:8888

      If the binary is blocked by Gatekeeper:
        xattr -cr #{libexec}/tune-server
    EOS
  end

  test do
    assert_match "tune-server", shell_output("#{bin}/tune-server --help 2>&1", 2)
  end
end
