#!/usr/bin/env ruby
require 'team_effort'

def do_cmd(cmd)
  `#{cmd}`
  raise "'#{cmd}' failed with #{status}" if !$?.success?
end

csv_file = ARGV[0]
lines = ARGV[1]
csv_file_name = File.basename(csv_file)
system "ghead -n 1 #{csv_file} > #{csv_file_name}_header"
system "gtail -n +2 #{csv_file} | gsplit -l #{lines} -a 3 - #{csv_file_name}_"
files = Dir.entries(".").reject { |f| f =~ %r{^(\.\.?|stdout|stderr)$} }
TeamEffort.work(files, 1) do |file|
  tmp_file = "tmp_#{file}"
  do_cmd "gcat #{csv_file_name}_header #{file} >> #{tmp_file}"
  do_cmd "mv #{tmp_file} #{file}"
end
do_cmd "rm #{csv_file_name}_header"
puts ""