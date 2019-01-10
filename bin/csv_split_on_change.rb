#!/usr/bin/env ruby
require 'csv'

def columns_changed?(previous_row, row, change_columns)
  changed = false
  change_columns.each do |column|
    changed ||= previous_row[column] != row[column]
  end
  changed
end

def file_name_from_changed_columns(row, change_columns)
  change_columns.map { |column| row[column] }.join("_") + ".csv"
end

change_columns = ARGV[0].split(/,/).map(&:to_i)
input_file = ARGV[1]

previous_row = output_csv = nil
CSV.foreach(input_file) do |row|
  if previous_row.nil? || (previous_row && columns_changed?(previous_row, row, change_columns))
    output_csv.close if output_csv
    output_file_name = file_name_from_changed_columns(row, change_columns)
    output_csv = CSV.open(output_file_name, "w")
  end
  output_csv << row
  previous_row = row
end
output_csv.close
