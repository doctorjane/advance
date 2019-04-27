require_relative "../lib/advance"
require "fileutils"
require "test_helper"
include Advance

describe "strip_extensions" do
  it "strips common extensions" do
    %w(
      foo.csv
      foo.csv.gz
      foo.csv.tar
      foo.geo_json
      foo.geojson
      foo.gz
      foo.json
      foo.tgz
    ).each do |file_name|
      strip_extensions(file_name).must_equal("foo")
    end
  end
end

def work_in_test_dir(test_dir)
  FileUtils.cd File.dirname(__FILE__)
  full_dir_path = File.expand_path(test_dir)
  FileUtils.rm_rf test_dir
  FileUtils.mkdir_p test_dir
  begin
    FileUtils.cd test_dir
    yield full_dir_path
  ensure
    FileUtils.cd File.dirname(__FILE__)
    FileUtils.rm_rf test_dir
  end
end

describe "work_in_sub_dir" do
  it "records results in a subdir without file extensions" do
    %w(foo.csv foo.gz foo.geojson foo.json).each do |dir_name|
      work_in_test_dir "advance_work_in_sub_dir" do
        work_in_sub_dir(dir_name) do
          File.write("test", "hello")
        end
        created_dirs = Dir.entries(".")
        created_dirs.must_equal(%w(. .. foo))
      end
    end
  end
end

describe "multi" do
  it "provides path and filename helpers" do
    %w(foo.csv foo.gz foo.geojson foo.json).each do |dir_name|
      test_dir = "advance_work_in_sub_dir"
      work_in_test_dir test_dir do |full_dir_path|
        FileUtils.touch "foo.csv"
        FileUtils.touch "bar.csv"

        $step = nil

        advance :multi, :mumble, "echo {input_file} and {file_name_without_extension} > {file_name}"

        created_files = Dir.entries(".")
        created_files.must_equal(%w(. .. .meta foo.csv bar.csv step_001_mumble))

        created_files = Dir.entries("./step_001_mumble")
        created_files.must_equal(%w(. .. foo bar))

        created_files = Dir.entries("./step_001_mumble/foo")
        created_files.must_equal(%w(. .. foo.csv log))
        contents = File.read("./step_001_mumble/foo/foo.csv")
        contents.must_equal("#{full_dir_path}/foo.csv and foo\n")

        created_files = Dir.entries("./step_001_mumble/bar")
        created_files.must_equal(%w(. .. bar.csv log))
        contents = File.read("./step_001_mumble/bar/bar.csv")
        contents.must_equal("#{full_dir_path}/bar.csv and bar\n")
      end
    end
  end

  it "output files go into the same structure as the input file" do
    work_in_test_dir "output_file_structure_mimics_input_structure" do
      FileUtils.mkdir_p "step_001_mumble/abc"
      FileUtils.mkdir_p "step_001_mumble/def"
      FileUtils.touch "step_001_mumble/abc/something_1.csv"
      FileUtils.touch "step_001_mumble/abc/something_2.csv"
      FileUtils.touch "step_001_mumble/abc/something_3.csv"
      FileUtils.touch "step_001_mumble/def/something_4.csv"

      Dir.glob("step_001_mumble/**/*").sort.must_equal %w(
        step_001_mumble/abc
        step_001_mumble/abc/something_1.csv
        step_001_mumble/abc/something_2.csv
        step_001_mumble/abc/something_3.csv
        step_001_mumble/def
        step_001_mumble/def/something_4.csv
      ).sort

      $step = 1

      advance :multi, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      Dir.glob("step_002_flagerize/**/*").sort.must_equal %w(
        step_002_flagerize/abc
        step_002_flagerize/abc/something_1
        step_002_flagerize/abc/something_1/log
        step_002_flagerize/abc/something_1/something_1.csv
        step_002_flagerize/abc/something_2
        step_002_flagerize/abc/something_2/log
        step_002_flagerize/abc/something_2/something_2.csv
        step_002_flagerize/abc/something_3
        step_002_flagerize/abc/something_3/log
        step_002_flagerize/abc/something_3/something_3.csv
        step_002_flagerize/def
        step_002_flagerize/def/something_4
        step_002_flagerize/def/something_4/log
        step_002_flagerize/def/something_4/something_4.csv
      ).sort
    end
  end

  it "maintains depth of tree on subsequent multi's" do
    work_in_test_dir "maintains_depth" do
      FileUtils.mkdir_p "step_002_mumble/abc/foo"
      FileUtils.mkdir_p "step_002_mumble/abc/bar"
      FileUtils.mkdir_p "step_002_mumble/def/baz"
      FileUtils.touch "step_002_mumble/abc/foo/foo.csv"
      FileUtils.touch "step_002_mumble/abc/bar/bar.csv"
      FileUtils.touch "step_002_mumble/def/baz/baz.csv"

      Dir.glob("step_002_mumble/**/*").sort.must_equal %w(
        step_002_mumble/abc
        step_002_mumble/abc/bar
        step_002_mumble/abc/bar/bar.csv
        step_002_mumble/abc/foo
        step_002_mumble/abc/foo/foo.csv
        step_002_mumble/def
        step_002_mumble/def/baz
        step_002_mumble/def/baz/baz.csv
      ).sort

      $step = 2
      $cores = 1

      advance :multi, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      Dir.glob("step_003_flagerize/**/*").sort.must_equal %w(
        step_003_flagerize/abc
        step_003_flagerize/abc/bar
        step_003_flagerize/abc/bar/bar.csv
        step_003_flagerize/abc/bar/log
        step_003_flagerize/abc/foo
        step_003_flagerize/abc/foo/foo.csv
        step_003_flagerize/abc/foo/log
        step_003_flagerize/def
        step_003_flagerize/def/baz
        step_003_flagerize/def/baz/baz.csv
        step_003_flagerize/def/baz/log
      ).sort
    end
  end

end

describe "single" do
  it "provides path and filename helpers" do
    work_in_test_dir "advance_work_in_sub_dir" do |test_dir|
      FileUtils.touch "foo.csv"

      $step = nil

      advance :single, :mumble, "echo {input_file} and {file_name_without_extension} > {file_name}"

      created_files = Dir.entries(".")
      created_files.must_equal(%w(. .. .meta foo.csv step_001_mumble))

      created_files = Dir.entries("./step_001_mumble")
      created_files.must_equal(%w(. .. foo.csv log))
      contents = File.read("./step_001_mumble/foo.csv")
      contents.must_equal("#{test_dir}/foo.csv and foo\n")
    end
  end

  it "when finished, zips the previous dir" do
    work_in_test_dir "zips_previous_dir" do |test_dir|
      FileUtils.mkdir "step_001_mumble"
      FileUtils.touch "step_001_mumble/something_1.csv"
      FileUtils.touch "step_001_mumble/something_2.csv"

      $step = 1

      advance :single, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      files = Dir.entries(".")
      files.sort.must_equal(%w(. .. .meta step_001_mumble.tgz step_002_flagerize).sort)
    end
  end

  it "does not zip the previous dir on step 1" do
    work_in_test_dir "zips_previous_dir" do |test_dir|
      FileUtils.mkdir "step_001_mumble"
      FileUtils.touch "step_001_mumble/something_1.csv"
      FileUtils.touch "step_001_mumble/something_2.csv"

      $step = 1

      advance :single, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      files = Dir.entries(".")
      files.sort.must_equal(%w(. .. .meta step_001_mumble.tgz step_002_flagerize).sort)
    end
  end

  it "when previous step was zipped, unzips to do work" do
    work_in_test_dir "unzips_previous_dir_fe959a0" do |test_dir|
      FileUtils.mkdir "step_001_mumble"
      FileUtils.touch "step_001_mumble/something_1.csv"
      FileUtils.touch "step_001_mumble/something_2.csv"
      system("tar czf step_001_mumble.tgz step_001_mumble")
      system("rm -rf step_001_mumble")

      $step = 1

      advance :single, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      files = Dir.entries(".")
      files.sort.must_equal(%w(. .. .meta step_001_mumble.tgz step_002_flagerize).sort)

      contents = File.read("./step_002_flagerize/something_1.csv")
      contents.must_equal("#{test_dir}/step_001_mumble/something_1.csv and something_1\n")
    end
  end

  describe "capture_column_names_from_csv" do
    it "set dollar column_names with the names from the csv file" do
      work_in_test_dir "capture_column_names_from_csv_197c6ba0" do |test_dir|
        FileUtils.mkdir "step_001_mumble"
        File.write("step_001_mumble/something_1.csv", <<CSV)
id,name,location,start_time
6134,Otter,"123 Park Ave, Oakland CA",2019-04-21 11:06:12
CSV
        $step = 1

        $column_names.must_be_nil
        capture_column_names_from_csv
        $column_names.must_equal %i{id name location start_time}
      end
    end
  end
end
