require 'minitest/autorun'

describe "csv_split_on_change_nh" do
  it "splits csv rows based on changed columns" do
    FileUtils.rm_rf("test_csv_split_on_change_nh")
    FileUtils.mkdir("test_csv_split_on_change_nh")
    begin
      file_contents = <<CSV
abc,111,555
abc,222,666
abc,222,333
def,333,777
CSV
      File.write("test_csv_split_on_change_nh_input_file", file_contents)
      FileUtils.chdir("test_csv_split_on_change_nh")
      csv_split_on_change_nh_bin = File.expand_path("../../bin/csv_split_on_change_nh.rb", __FILE__)

      results = `#{csv_split_on_change_nh_bin} 0,1 ../test_csv_split_on_change_nh_input_file`
      status = $?
      if !status.success?
        puts "======================"
        puts results
        puts "======================"
      end
      status.must_be :success?

      files_in_tmp_dir = Dir.entries(".")
      files_in_tmp_dir.must_equal(%w(. .. abc_111.csv abc_222.csv def_333.csv))
      File.read("abc_111.csv").must_equal("abc,111,555\n")
      File.read("abc_222.csv").must_equal("abc,222,666\nabc,222,333\n")
      File.read("def_333.csv").must_equal("def,333,777\n")

    ensure
      FileUtils.chdir("..")
      FileUtils.rm_rf("test_csv_split_on_change_nh")
      FileUtils.rm("test_csv_split_on_change_nh_input_file")
    end
  end
end

