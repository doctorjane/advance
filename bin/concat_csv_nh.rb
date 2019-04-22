#!/usr/bin/env ruby

require "find"

def do_cmd(cmd)
  system cmd
  status = $?
  raise "'#{cmd}' failed with #{status}" if !status.success?
end

files_dir_path = ARGV[0]
output_file = ARGV[1]
files = Find.find(files_dir_path).reject { |p| FileTest.directory?(p) || File.basename(p) == "log" }

files.each_slice(20) do |files_to_concat|
  file_list = files_to_concat.join(' ')
  do_cmd "cat #{file_list} >> #{output_file}"
end
