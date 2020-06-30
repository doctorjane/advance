require "csv"
require "fileutils"
require "find"
require "json"
require "open3"
require "team_effort"
require_relative "./advance/version"

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

  def env_is?(env_var_name, default)
    case ENV[env_var_name]
    when "true"; true
    when "false"; false
    when nil; default
    else
      puts "env variable #{env_var_name} should be 'true', 'false', or not present (defaults to '#{default}')"
      puts "currently set to >#{ENV[env_var_name]}<"
      false
    end
  end

  def self.included(pipeline_module)
    $pipeline = caller_locations.first.path
    meta =
      if File.exist?(".meta")
        JSON.parse(File.read(".meta"))
      else
        {}
      end
    last_run_number = meta["last_run_number"] ||= -1
    $run_number = last_run_number + 1
    $cores=`nproc`.to_i
    puts "Multi steps will use #{$cores} cores"
  end

  def update_meta(step_number, processing_mode, label, command, start_time, duration, file_count)
    meta =
      if File.exist?(".meta")
        JSON.parse(File.read(".meta"))
      else
        {}
      end

    meta["pipeline"] ||= $pipeline
    meta["last_run_number"] = $run_number
    meta["runs"] ||= []

    step_data = {
      "step_number" => step_number,
      "start_time" => start_time,
      "duration" => duration,
      "file_count" => file_count,
      "processing_mode" => processing_mode,
      "label" => label,
      "command" => command,
      "columns" => $column_names
    }
    meta["runs"][$run_number] ||= []
    meta["runs"][$run_number] << step_data

    File.write(".meta", JSON.pretty_generate(meta))
  end

  def capture_column_names_from_csv
    if $step.nil?
      raise "capture_column_names_from_csv cannot be the first step"
    end

    if File.exist?(".meta")
      if read_column_names_from_meta
        return
      end
    end

    previous_dir_path = get_previous_dir_path
    input_file_path = previous_file_path(previous_dir_path)
    CSV.foreach(input_file_path, :headers => true) do |row|
      $column_names = row.headers.map(&:to_sym)
      break
    end
  end

  def read_column_names_from_meta
    meta = JSON.parse(File.read(".meta"))
    meta["runs"].each do |run|
      run.each do |step|
        if step["columns"]
          $column_names = step["columns"].map(&:to_sym)
          return true
        end
      end
    end
    false
  end

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
      start_time = Time.now
      send(processing_mode, command, previous_dir_path, dir_name)
      file_count = count_files(dir_name)
      duration = Time.now - start_time
      update_meta($step, processing_mode, label, command, start_time, duration, file_count)
    end
    previous_dir_path = previous_dir_path.gsub(/\.tgz$/, "")
    if File.basename(previous_dir_path) =~ /^step_/
      if env_is?("ADVANCE_SAVE_HISTORY", true) && !File.exist?("#{previous_dir_path}.tgz")
        do_command_wo_log "tar czf #{previous_dir_path}.tgz #{File.basename(previous_dir_path)}"
      end
      do_command_wo_log "rm -rf #{previous_dir_path}"
    end
  end

  def pipeline(pipeline_path)
    load pipeline_path
  end

  def count_files(dir)
    file_count = 0
    Find.find(dir) do |path|
      next if File.directory?(path)
      next if File.basename(path) == "log"
      next if File.basename(path) =~ /^\./
      file_count += 1
    end
    file_count
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
      command.gsub!("{input_dir}", previous_dir_path)
      input_file_path = previous_file_path(previous_dir_path)
      if input_file_path
        basename = File.basename(input_file_path)
        root_file_name = basename.gsub(%r(\.[^.]+$), '')
        command.gsub!("{input_file}", input_file_path)
        command.gsub!("{file_name}", basename)
        command.gsub!("{file_name_without_extension}", root_file_name)
      end
      do_command command
    end
  end

  def multi(command, previous_dir_path, dir_name)
    work_in_sub_dir(dir_name) do
      file_paths = Find.find(previous_dir_path).reject { |p| File.basename(p) =~ %r(^\.) || FileTest.directory?(p) || File.basename(p) == "log" }

      last_progress = ""
      progress_proc = ->(index, max_index) do
        latest_progress = sprintf("%3i%%", index.to_f / max_index * 100)
        puts latest_progress if last_progress != latest_progress
        last_progress = latest_progress
      end
      TeamEffort.work(file_paths, $cores, progress_proc: progress_proc) do |file_path|
        begin
          path_relative_to_step_dir = File.dirname(file_path.gsub(%r(^#{previous_dir_path}/?), ""))
          path_relative_to_step_dir = path_relative_to_step_dir == "." ? "" : path_relative_to_step_dir
          basename = File.basename(file_path)
          new_dir_name = path_relative_to_step_dir == "" ? basename : File.join(path_relative_to_step_dir, basename)
          root_file_name = basename.gsub(%r(\.[^.]+$), '')

          command.gsub!("{input_dir}", File.dirname(file_path))
          command.gsub!("{input_file}", file_path)
          command.gsub!("{file_name}", basename)
          command.gsub!("{file_name_without_extension}", root_file_name)
          puts "#{YELLOW}#{command}#{RESET}  " if env_is?("ADVANCE_VERBOSE_LOGGING", false)
          work_in_sub_dir(new_dir_name) do
            do_command command, env_is?("ADVANCE_VERBOSE_LOGGING", false)
          end
          do_command_wo_log("rm #{file_path}", false) if !env_is?("ADVANCE_SAVE_HISTORY", true)
        rescue
          puts "%%%% error while processing >>#{file_path}<<"
          raise
        end
      end
    end
  end

  def work_in_sub_dir(dir_name)
    starting_dir = FileUtils.pwd
    stripped_dir_name = File.join(*(strip_extensions(dir_name).split("/").uniq))
    if $redo_mode == :checking && Dir.exist?(stripped_dir_name)
      return
    end

    $redo_mode = :replacing

    dirs = stripped_dir_name.split("/")
    dirs[-1] = "tmp_#{dirs[-1]}"
    tmp_dir = File.join(dirs)
    FileUtils.rm_rf tmp_dir
    FileUtils.mkdir_p tmp_dir
    FileUtils.cd tmp_dir

    yield

    FileUtils.cd starting_dir
    FileUtils.mv tmp_dir, stripped_dir_name
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
    $LOAD_PATH << File.expand_path(File.join(caller_locations.first.path, "../../lib"))

    advance_bin_path = File.expand_path(File.join(File.dirname(__FILE__), "../bin"))
    add_dir_to_path(advance_bin_path)

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
