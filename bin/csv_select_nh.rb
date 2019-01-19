#!/usr/bin/env ruby
require 'csv'

test_proc = eval "lambda {|row| #{ARGV.shift}}"

input = CSV.new(ARGF, :converters => :numeric)
output = CSV.new($stdout)

input.each do |row|
  if test_proc.call(row)
    output << row
  end
end
