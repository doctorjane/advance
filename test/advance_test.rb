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
