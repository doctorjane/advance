require 'minitest/autorun'

describe "csv_select_nh" do
  it "filters csv rows based on the ruby expression" do
    tmp_file = Tempfile.new('csv_file')
    begin
      csv = <<CSV
abc,111,555
abc,222,666
CSV
      tmp_file.write(csv)
      tmp_file.rewind

      expected = <<CSV
abc,222,666
CSV
      csv_select_bin = File.expand_path("../../bin/csv_select_nh.rb", __FILE__)
      output = `#{csv_select_bin} "row[2]==666" < #{tmp_file.path}`

      output.must_equal(expected)

    ensure
      tmp_file.close
      tmp_file.unlink
    end
  end
end
