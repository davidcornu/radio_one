require 'tempfile'

require_relative './shell_command'

module FFmpeg
  def self.concatenate!(files, output_file)
    manifest_file = Tempfile.new("ffmpeg-manifest")
    manifest_file.write(files.map { |f| "file '#{f}'" }.join("\n") + "\n")
    manifest_file.close
    
    ShellCommand.run!(
      "ffmpeg",
      "-f", "concat",
      "-i", manifest_file.path,
      "-vn",
      "-acodec", "copy",
      output_file
    )

    output_file
  ensure
    manifest_file.unlink if manifest_file
  end
end
