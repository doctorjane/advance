require 'minitest/autorun'

describe "csv_split_on_change" do
  it "splits csv rows based on changed columns" do
    FileUtils.rm_rf("test_csv_split_on_change")
    FileUtils.mkdir("test_csv_split_on_change")
    file_contents = <<CSV
abc,111,555
abc,222,666
abc,222,333
def,333,777
CSV
    File.write("test_csv_split_on_change_input_file", file_contents)
    FileUtils.chdir("test_csv_split_on_change")
    csv_split_on_change_bin = File.expand_path("../bin/csv_split_on_change.rb")

    system csv_split_on_change_bin, "0,1", "../test_csv_split_on_change_input_file"
    status = $?
    status.must_be :success?

    files_in_tmp_dir = Dir.entries(".")
    files_in_tmp_dir.must_equal(%w(. .. abc_111.csv abc_222.csv def_333.csv))
    File.read("abc_111.csv").must_equal("abc,111,555\n")
    File.read("abc_222.csv").must_equal("abc,222,666\nabc,222,333\n")
    File.read("def_333.csv").must_equal("def,333,777\n")

    FileUtils.chdir("..")
    FileUtils.rm_rf("test_csv_split_on_change")
    FileUtils.rm("test_csv_split_on_change_input_file")
  end
end

