require "fileutils"

class FilePathGenerator
  def initialize(max_entries_per_dir = 10_000)
    @max_entries_per_dir = max_entries_per_dir
    @entry_counts = [0]
    @dir_mask = "%0#{max_entries_per_dir.to_s.length}d"
  end

  def path_for_new_file(file_name)
    increment_dir_counter
    return file_name if @entry_counts.size == 1

    dir_paths = @entry_counts[1..-1].reverse.map{|n| @dir_mask % [n - 1] }
    dir_path = File.join(".", *dir_paths)
    FileUtils.mkdir_p(dir_path)
    File.join(dir_path, file_name)
  end

  def increment_dir_counter(dir_depth = 0)
    if dir_depth > (@entry_counts.size - 1)
      @entry_counts << 2
      indent_dirs
      return
    end

    @entry_counts[dir_depth] += 1

    if @entry_counts[dir_depth] > @max_entries_per_dir
      @entry_counts[dir_depth] = 1
      increment_dir_counter(dir_depth + 1)
    end
  end


  def indent_dirs
    tmp_dir_name = "tmp_#{@entry_counts.size}"
    FileUtils.mkdir tmp_dir_name
    Dir.entries(".").each do |existing_dir|
      next if existing_dir =~ %r(\.\.?)
      next if existing_dir == tmp_dir_name
      FileUtils.mv existing_dir, tmp_dir_name
    end
    new_dir_name = @dir_mask % [0]
    FileUtils.mv tmp_dir_name, new_dir_name
  end

  def to_s
    "[ #{@entry_counts.join(',')} ]"
  end
end

