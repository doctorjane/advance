require_relative "./advance/version"
require "find"
require "fileutils"
require "open3"
require "team_effort"

module Advance
  RESET="\e[0m"

  BOLD="\e[1m"
  ITALIC="\e[3m"
  UNDERLINE="\e[4m"

  CYAN="\e[36m"
  GRAY="\e[37m"
  GREEN="\e[32m"
  MAGENTA="\e[35m"
  RED="\e[31m"
  WHITE="\e[1;37m"
  YELLOW="\e[33m"

  puts "loading module"

  def advance(processing_mode, label, command)
    $redo_mode ||= :checking
    $step ||= 0
    previous_dir_path = get_previous_dir_path

    $step += 1
    dir_prefix = step_dir_prefix($step)
    dir_name = "#{dir_prefix}_#{label}"

    puts "#{CYAN}advance #{$step} #{label}#{WHITE}... #{RESET}"

    if $redo_mode != :checking || !(File.exist?(dir_name) || File.exist?(dir_name + '.tgz'))
      clean_previous_step_dirs(dir_prefix)

      if previous_dir_path =~ /\.tgz$/
        do_command_wo_log "tar xzf #{previous_dir_path}"
      end
      previous_dir_path = previous_dir_path.gsub(/\.tgz$/, "")
      send(processing_mode, command, previous_dir_path, dir_name)
    end
    previous_dir_path = previous_dir_path.gsub(/\.tgz$/, "")
    if File.basename(previous_dir_path) =~ /^step_/
      if !File.exist?("#{previous_dir_path}.tgz")
        do_command_wo_log "tar czf #{previous_dir_path}.tgz #{File.basename(previous_dir_path)}"
      end
      do_command_wo_log "rm -rf #{previous_dir_path}"
    end
  end

  def static(processing_mode, label, command)
    $redo_mode ||= :checking
    $step ||= 0
    previous_dir_path = get_previous_dir_path
    dir_prefix = static_dir_prefix($step)
    dir_name = "#{dir_prefix}_#{label}"
    puts "#{CYAN}static #{$step} #{label}#{WHITE}... #{RESET}"
    return if $redo_mode == :checking && Dir.exist?(dir_name)

    FileUtils.rm_rf dir_name

    send(processing_mode, command, previous_dir_path, dir_name)
  end

  def get_previous_dir_path
    relative_path = case $step
                    when 0
                      "."
                    else
                      File.join(".", Dir.entries(".").find { |d| d =~ /^#{step_dir_prefix($step)}/ })
                    end
    File.expand_path(relative_path)
  end

  def step_dir_prefix(step_no)
    "step_%03d" % [step_no]
  end

  def static_dir_prefix(step_no)
    "static_%03d" % [step_no]
  end

  def clean_previous_step_dirs(dir_prefix)
    while (step_dir = find_step_dir(dir_prefix))
      puts "## removing #{step_dir}"
      FileUtils.rm_rf step_dir
    end
  end

  def find_step_dir(dir_prefix)
    dirs = Dir.entries(".")
    dirs.find { |d| d =~ /^#{dir_prefix}/ }
  end

  def single(command, previous_dir_path, dir_name)
    work_in_sub_dir(dir_name) do
      input_file_path = previous_file_path(previous_dir_path)
      basename = File.basename(input_file_path)
      root_file_name = basename.gsub(%r(\.[^.]+$), '')

      command.gsub!("{input_dir}", previous_dir_path)
      command.gsub!("{input_file}", input_file_path)
      command.gsub!("{file_name}", basename)
      command.gsub!("{file_name_without_extension}", root_file_name)

      do_command command
    end
  end

  def multi(command, previous_dir_path, dir_name)
    no_feedback = false
    work_in_sub_dir(dir_name) do
      file_paths = Find.find(previous_dir_path).reject { |path| FileTest.directory?(path) || File.basename(path) == "log" }

      last_progress = ""
      progress_proc = ->(index, max_index) do
        latest_progress = sprintf("%3i%", index.to_f / max_index * 100)
        puts latest_progress if last_progress != latest_progress
        last_progress = latest_progress
      end
      TeamEffort.work(file_paths, $cores, progress_proc: progress_proc) do |file_path|
        begin
          basename = File.basename(file_path)
          root_file_name = basename.gsub(%r(\.[^.]+$), '')

          command.gsub!("{input_file}", file_path)
          command.gsub!("{file_name}", basename)
          command.gsub!("{file_name_without_extension}", root_file_name)
          puts "#{YELLOW}#{command}#{RESET}"
          work_in_sub_dir(basename) do
            do_command command, no_feedback
          end
        rescue
          puts "%%%% error while processing >>#{file_path}<<"
          raise
        end
      end
    end
  end

  def work_in_sub_dir(dir_name)
    stripped_dir_name = strip_extensions(dir_name)
    if $redo_mode == :checking && Dir.exist?(stripped_dir_name)
      return
    end

    $redo_mode = :replacing

    tmp_dir_name = "tmp_#{stripped_dir_name}"
    FileUtils.rm_rf tmp_dir_name
    FileUtils.mkdir_p tmp_dir_name
    FileUtils.cd tmp_dir_name

    yield

    FileUtils.cd ".."
    FileUtils.mv tmp_dir_name, stripped_dir_name
  end

  def strip_extensions(dir_name)
    extensions = %w(
      csv
      csv_nh
      geo_json
      geojson
      gz
      json
      tar
      tgz
      zip
    )

    changed_dir_name = dir_name
    last_dir_name = nil
    until last_dir_name == changed_dir_name do
      last_dir_name = changed_dir_name
      extensions.each do |extension|
        changed_dir_name = changed_dir_name.gsub(%r(\.#{extension}$), "")
      end
    end
    changed_dir_name
  end

  def previous_file_path(previous_dir_path)
    Find.find(previous_dir_path).reject {|p| File.basename(p) =~ %r(^\.) || FileTest.directory?(p) || File.basename(p) == "log"}.first
  end

  def file_path_template(dir_path, files)
    file = files.first
    file_path = File.join(dir_path, file)
    if File.directory?(file_path)
      File.join(dir_path, "{file}", "{file}")
    else
      File.join(dir_path, "{file}")
    end
  end

  def do_command(command, feedback = true)
    puts "#{YELLOW}#{command}#{RESET}  " if feedback
    start_time = Time.now
    stdout, stderr, status = Open3.capture3(command)
    elapsed_time = Time.now - start_time
    File.open("log", "w") do |f|
      f.puts "%%% command: >#{command}<"
      f.puts "%%% returned status: >#{status}<"
      f.puts "%%% elapsed time: #{elapsed_time} seconds"
      f.puts "%%% stdout:"
      f.puts stdout
      f.puts "%%% stderr:"
      f.puts stderr
    end
    if !status.success?
      raise "step #{$step} failed with #{status}\n#{stderr}"
    end
  end

  def do_command_wo_log(command, feedback = true)
    puts "#{YELLOW}#{command}#{RESET}  " if feedback
    stdout, stderr, status = Open3.capture3(command)
    if !status.success?
      error_msg = [
        "step #{$step} failed",
        "%%% command: >#{command}<",
        "%%% returned status: >#{status}<",
        "%%% stdout:",
        stdout,
        "%%% stderr:",
        stderr
      ].join("\n")

      raise error_msg
    end
  end

  def ensure_bin_on_path
    advance_path = File.dirname(__FILE__)
    add_dir_to_path(advance_path)

    caller_path = File.dirname(caller[0].split(/:/).first)
    add_dir_to_path(caller_path)
  end

  def add_dir_to_path(dir)
    bin_dir = File.expand_path(dir)
    path = ENV["PATH"]

    return if path.include?(bin_dir)
    ENV["PATH"] = [path, bin_dir].join(":")
  end
end
