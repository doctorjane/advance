#!/usr/bin/env ruby

require "find"
require "team_effort"

def do_cmd(cmd)
  system cmd
  status = $?
  raise "'#{cmd}' failed with #{status}" if !status.success?
end

files_dir_path = ARGV[0]
output_file = ARGV[1]
files = Find.find(files_dir_path).reject { |p| FileTest.directory?(p) || p =~ %r(\b(stdout|stderr)$) }

# 1. capture the header from the first file
do_cmd "ghead -n 1 #{files.first} > header"

# 2. strip the header from all files
TeamEffort.work(files) do |file_path|
  file = File.basename(file_path)
  do_cmd "gtail -n +2 #{file_path} > #{file}"
end

# 3. concate the header and all files
tmp_files = files.map{|f| File.basename(f)}
(["header"] + tmp_files).each_slice(20) do |files_to_concat|
  file_list = files_to_concat.join(' ')
  do_cmd "gcat #{file_list} >> #{output_file}"
  do_cmd "rm #{file_list}"
end
