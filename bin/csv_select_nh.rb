#!/usr/bin/env ruby
require 'csv'
# $stderr.puts "#{__FILE__}:#{__LINE__}"

test_proc = eval "lambda {|row| #{ARGV.shift}}"

input = CSV.new(ARGF, :headers => true, :return_headers => true, :converters => :numeric)
output = CSV.new($stdout, :headers => true, :write_headers => true)

input.each.with_index do |row, index|
  # $stderr.puts "#{index}: >>#{row.to_s.chomp}<<"
  if row.header_row?
    output << row
    next
  end

  if test_proc.call(row)
    output << row
    next
  end
end
