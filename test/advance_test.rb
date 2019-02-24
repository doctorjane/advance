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

describe "work_in_sub_dir" do
  it "records results in a subdir without file extensions" do
    test_dir = File.join(FileUtils.pwd, "advance_work_in_sub_dir_97169ae")

    %w(foo.csv foo.gz foo.geojson foo.json).each do |dir_name|
      FileUtils.rm_rf test_dir
      FileUtils.mkdir_p test_dir
      begin
        FileUtils.cd test_dir

        work_in_sub_dir(dir_name) do
          File.write("test", "hello")
        end

        FileUtils.cd test_dir
        created_dirs = Dir.entries(".")
        created_dirs.must_equal(%w(. .. foo))
      ensure
        FileUtils.rm_rf test_dir
      end
    end
  end
end

describe "multi" do
  it "provides path and filename helpers" do
    FileUtils.cd File.dirname(__FILE__)
    test_dir = File.join(File.dirname(__FILE__), "advance_work_in_sub_dir_dab3a3c")

    %w(foo.csv foo.gz foo.geojson foo.json).each do |dir_name|
      FileUtils.rm_rf test_dir
      FileUtils.mkdir_p test_dir
      begin
        FileUtils.cd test_dir
        FileUtils.touch "foo.csv"
        FileUtils.touch "bar.csv"

        $step = nil

        advance :multi, :mumble, "echo {input_file} and {file_name_without_extension} > {file_name}"

        created_files = Dir.entries(".")
        created_files.must_equal(%w(. .. foo.csv bar.csv step_001_mumble))

        created_files = Dir.entries("./step_001_mumble")
        created_files.must_equal(%w(. .. foo bar))

        created_files = Dir.entries("./step_001_mumble/foo")
        created_files.must_equal(%w(. .. foo.csv log))
        contents = File.read("./step_001_mumble/foo/foo.csv")
        contents.must_equal("#{test_dir}/foo.csv and foo\n")

        created_files = Dir.entries("./step_001_mumble/bar")
        created_files.must_equal(%w(. .. bar.csv log))
        contents = File.read("./step_001_mumble/bar/bar.csv")
        contents.must_equal("#{test_dir}/bar.csv and bar\n")

      ensure
        FileUtils.cd File.dirname(__FILE__)
        FileUtils.rm_rf test_dir
      end
    end
  end
end

describe "single" do
  it "provides path and filename helpers" do
    FileUtils.cd File.dirname(__FILE__)
    test_dir = File.join(File.dirname(__FILE__), "advance_work_in_sub_dir_dab3a3c")

    FileUtils.rm_rf test_dir
    FileUtils.mkdir_p test_dir
    begin
      FileUtils.cd test_dir
      FileUtils.touch "foo.csv"

      $step = nil

      advance :single, :mumble, "echo {input_file} and {file_name_without_extension} > {file_name}"

      created_files = Dir.entries(".")
      created_files.must_equal(%w(. .. foo.csv step_001_mumble))

      created_files = Dir.entries("./step_001_mumble")
      created_files.must_equal(%w(. .. foo.csv log))
      contents = File.read("./step_001_mumble/foo.csv")
      contents.must_equal("#{test_dir}/foo.csv and foo\n")

    ensure
      FileUtils.cd File.dirname(__FILE__)
      FileUtils.rm_rf test_dir
    end
  end

  it "when finished, zips the previous dir" do
    FileUtils.cd File.dirname(__FILE__)
    test_dir = File.join(File.dirname(__FILE__), "zips_previous_dir_fe959a0")
    FileUtils.rm_rf test_dir
    FileUtils.mkdir_p test_dir
    begin
      FileUtils.cd test_dir
      FileUtils.mkdir "step_001_mumble"
      FileUtils.touch "step_001_mumble/something_1.csv"
      FileUtils.touch "step_001_mumble/something_2.csv"

      $step = 1

      advance :single, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      files = Dir.entries(".")
      files.sort.must_equal(%w(. .. step_001_mumble.tgz step_002_flagerize).sort)

    ensure
      FileUtils.cd File.dirname(__FILE__)
      FileUtils.rm_rf test_dir
    end
  end

  it "does not zip the previous dir on step 1" do
    FileUtils.cd File.dirname(__FILE__)
    test_dir = File.join(File.dirname(__FILE__), "zips_previous_dir_fe959a0")
    FileUtils.rm_rf test_dir
    FileUtils.mkdir_p test_dir
    begin
      FileUtils.cd test_dir
      FileUtils.mkdir "step_001_mumble"
      FileUtils.touch "step_001_mumble/something_1.csv"
      FileUtils.touch "step_001_mumble/something_2.csv"

      $step = 1

      advance :single, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      files = Dir.entries(".")
      files.sort.must_equal(%w(. .. step_001_mumble.tgz step_002_flagerize).sort)

    ensure
      FileUtils.cd File.dirname(__FILE__)
      FileUtils.rm_rf test_dir
    end
  end

  it "when previous step was zipped, unzips to do work" do
    FileUtils.cd File.dirname(__FILE__)
    test_dir = File.join(File.dirname(__FILE__), "unzips_previous_dir_fe959a0")
    FileUtils.rm_rf test_dir
    FileUtils.mkdir_p test_dir
    begin
      FileUtils.cd test_dir
      FileUtils.mkdir "step_001_mumble"
      FileUtils.touch "step_001_mumble/something_1.csv"
      FileUtils.touch "step_001_mumble/something_2.csv"
      system("tar czf step_001_mumble.tgz step_001_mumble")
      system("rm -rf step_001_mumble")

      $step = 1

      advance :single, :flagerize, "echo {input_file} and {file_name_without_extension} > {file_name}"

      files = Dir.entries(".")
      files.sort.must_equal(%w(. .. step_001_mumble.tgz step_002_flagerize).sort)

      contents = File.read("./step_002_flagerize/something_1.csv")
      contents.must_equal("#{test_dir}/step_001_mumble/something_1.csv and something_1\n")

    ensure
      FileUtils.cd File.dirname(__FILE__)
      FileUtils.rm_rf test_dir
    end
  end
end
