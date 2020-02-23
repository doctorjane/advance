#!/usr/bin/env ruby
require 'team_effort'

def do_cmd(cmd)
  `#{cmd}`
  raise "'#{cmd}' failed with #{status}" if !$?.success?
end

csv_file = ARGV[0]
lines = ARGV[1]
csv_file_name = File.basename(csv_file)
header_file_name = "#{csv_file_name}_header"
system "head -n 1 #{csv_file} > #{header_file_name}"
system "tail -n +2 #{csv_file} | split -l #{lines} -a 3 - #{csv_file_name}_"
files = Dir.entries(".").reject { |f| f.end_with?(header_file_name) || f =~ %r{^(\.\.?|log)$} }
TeamEffort.work(files, 1) do |file|
  tmp_file = "tmp_#{file}"
  do_cmd "cat #{header_file_name} #{file} >> #{tmp_file}"
  do_cmd "mv #{tmp_file} #{file}"
end
do_cmd "rm #{header_file_name}"
do_cmd "rename 's/^(.*)\.csv_(.*)$/$1_$2.csv/' *csv*"
puts ""