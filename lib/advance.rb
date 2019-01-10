require "advance/version"
require 'open3'

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
      raise "step #{$step} #{label} failed with #{status}"
    end
  end

  def previous_dir_path
    relative_path = case $step
                    when 1
                      ".."
                    else
                      File.join("..", Dir.entries("..").find { |d| d =~ /^#{step_dir_prefix($step - 1)}/ })
                    end
    File.expand_path(relative_path)
  end

  def previous_file_path
    dir_entries = Dir.glob(File.join(previous_dir_path, "*"))
    dir_entries_clean = dir_entries.reject { |f| File.directory?(f) || f =~ %r{^\.\.?|log} }
    dir_entries_clean.first
  end

  def single(label, command)
    step(label) do
      if command =~ /\{previous_file\}/
        command.gsub!("{previous_file}", previous_file_path)
      end
      if command =~ /\{previous_dir\}/
        command.gsub!("{previous_dir}", previous_dir_path)
      end
      do_command command
    end
  end

  def multi(label, command)
    no_feedback = false
    step(label) do
      # previous_dir_path = File.expand_path(previous_dir_path)
      files = Dir.entries(previous_dir_path).reject { |f| f =~ %r{^(\.\.?|log)$} }
      file_path_template = file_path_template(previous_dir_path, files)
      last_progress = ""
      progress_proc = ->(index, max_index) do
        latest_progress = sprintf("%3i%", index.to_f / max_index * 100)
        puts latest_progress if last_progress != latest_progress
        last_progress = latest_progress
      end
      TeamEffort.work(files, $cores, progress_proc: progress_proc) do |file|
        begin
          previous_file_path = file_path_template.gsub("{file}", file)
          command.gsub!("{file_path}", previous_file_path) unless $step == 1
          command.gsub!("{file}", file) unless $step == 1
          puts "#{YELLOW}#{command}#{RESET}"
          dir_name = file
          work_in_sub_dir(dir_name) do
            do_command command, no_feedback
          end
        rescue
          puts "%%%% error while processing >>#{file}<<"
          raise
        end
      end
    end
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

  def work_in_sub_dir(dir_name, existing_message = nil)
    return if Dir.exist? dir_name

    tmp_dir_name = "tmp_#{dir_name}"
    FileUtils.rm_rf tmp_dir_name
    FileUtils.mkdir_p tmp_dir_name
    FileUtils.cd tmp_dir_name

    yield

    FileUtils.cd ".."
    FileUtils.mv tmp_dir_name, dir_name
  end

  def step_dir_prefix(step_no)
    "step_%03d" % [step_no]
  end

  def step(label)
    $step ||= 0
    $step += 1
    dir_name = "#{step_dir_prefix($step)}_#{label}"
    $previous_dir = File.join(FileUtils.pwd, dir_name)
    puts "#{CYAN}step #{$step} #{label}#{WHITE}... #{RESET}"

    work_in_sub_dir(dir_name, "#{GREEN}OK#{RESET}") do
      yield
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
