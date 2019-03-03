require "find"
require "minitest/autorun"
require_relative "../lib/path_for_new_file"

describe "path_for_new_file" do
  it "moves files to a sub dir and adds a subdir to the new file path when the count exceeds the max" do
    base_dir = File.dirname(__FILE__)
    FileUtils.cd base_dir
    test_dir = "test_pfnf"
    FileUtils.rm_rf(test_dir)
    FileUtils.mkdir(test_dir)
    begin
      FileUtils.chdir(test_dir)

      file_path_generator = FilePathGenerator.new(2)

      "a".upto("b") do |i|
        path = file_path_generator.path_for_new_file(i.to_s)
        path.must_equal "#{i}"
        FileUtils.touch(path)
      end

      Dir.glob("./**/*").must_equal %w(./a ./b)

      "c".upto("d") do |i|
        path = file_path_generator.path_for_new_file(i.to_s)
        path.must_equal "./1/#{i}"
        FileUtils.touch(path)
      end

      Dir.glob("./**/*").sort.must_equal %w(
        ./0
        ./1
        ./0/a
        ./0/b
        ./1/c
        ./1/d
      ).sort

      "e".upto("f") do |i|
        path = file_path_generator.path_for_new_file(i.to_s)
        path.must_equal "./1/0/#{i}"
        FileUtils.touch(path)
      end

      Dir.glob("./**/*").sort.must_equal %w(
        ./0
        ./1
        ./0/0
        ./0/1
        ./1/0
        ./0/0/a
        ./0/0/b
        ./0/1/c
        ./0/1/d
        ./1/0/e
        ./1/0/f
      ).sort

    ensure
      FileUtils.chdir(base_dir)
      FileUtils.rm_rf(test_dir)
    end
  end
end

