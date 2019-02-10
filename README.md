# Advance

Advance is a framework for building data transformation pipelines.
Advance allows you to concisely script your 
data transformation process and to 
incrementally build and easily debug that process.
Each data transformation is a step and the results of each
step become the input to the next step. 

The artifacts of each step are preserved in step named directories. 
When the results of a step are not right, just
adjust the Advance script, delete the step directory with the bad data and 
rerun the script. Previously successful steps are skipped so the script
moves quickly to the incomplete step. Similarly, when steps fail the results
are preserved in directories prefixed with "tmp_". This isolates incomplete
step data and ensures that the step is re-processed when the problem is 
resolved.

Your project utilizing Advance contains a primary ruby script
that imports Advance and includes your data transformation steps,
which we will call "your Advance script."
Each step describes a command to be run on your data. These commands can be
one of the prepackaged Advance scripts, unix commands (like split, cut,
etc), or scripts/commands that you create in whatever language is 
convenient for you. Advance invokes these scripts one by one much like
you would at the command line. Advance logs the exact command that is invoked
so that you can run it yourself to check the output manually and to 
debug failures.

Advance steps are composed of a step processing type function, followed 
by a slug for the step, followed by the command or script. For example:

```ruby
single :unzip_7z_raw_data_file, "7z x {previous_file}"
single :split_files, "split -l 10000 -a 3 {previous_file} gps_data_"
multi :add_local_time, "cat {file_path} | add_local_time.rb timestamp local_time US/Pacific > {file}"
# ...
```

The step processing functions are `single` and `multi`. `Single` applies the command
to the last output, which should be a single file. `Multi` speeds processing of multiple
files by doing work in parallel (via the [TeamEffort gem][1]).

[1]: https://rubygems.org/gems/team_effort

> _[Advance][2]: To help the progress of (something); to further._

[2]: https://en.wiktionary.org/wiki/advance

## Installation

Advance is meant to augment a standalone ruby script. The advance gem needs to be 
available to your instance of ruby. Here are 2 techniques to make Advance available
to your script:

 * simply install the gem:

    $ gem install advance
    
 * install [bundler][3], and add Advance to your `Gemfile`:
 
[3]: https://rubygems.org/gems/bundler
 
```ruby
source "https://rubygems.org"

gem "advance"
# other gems...
```

## Usage

You will likely need multiple supporting scripts. Ideally you will
create your Advance script and your supporting scripts in a single directory.

Creating your Advance script is an incremental process. Start with a single 
step, run the script and check the results. When the output is as you expect,
add the next step. After you add a step to your script you can simply rerun
the script. Previously successful steps are skipped and your script moves on 
to the first incomplete step.

When the results are not what you expect, just delete the step directory with
the bad data, adjust your step, and rerun. Advance will rerun that step and 
all subsequent steps.

Steps have 3 components:

 * a step processing type (single or multi)
 * a descriptive slug describing the step (as a ruby symbol)
 * the command that transforms the data

Advance adds the bin dir of the Advance gem to PATH, so that you can invoke the 
supporting advance scripts in your pipeline without specifying the full path
of the script. Advance also adds the path of _your Advance script_ to PATH so 
that you can invoke scripts in the same directory as your main script without 
specifying the full path of the script. Of course, you can invoke any script 
if the path to the script is fully specified or the path is already on PATH.

**Specifying Script Input and Output**

Since your command is transforming data, you need a way to specify the input 
file or directory and the output file name. Advance provides a few tokens 
that can be inserted in the command string for this purpose:

 * **`{input_file}`** indicates the output file from the previous. It is also used
   to indicate the first file to be used and it finds that file in the current 
   working dir.
 * **`{file_name}`** indicates an output file name, which is the basename from 
   `{input_file}`. Commands often process multiple files from previous steps, 
   generating multiple output files. Those output files are placed in the
   step directory.
 * **`{file_name_without_extension}`** is, well, {file_name} with the 
   extension removed. This is useful when you are transforming a file from
   one type (with an extension) to another type, with a new extension.
 * **`{input_dir}`** indicates the directory of the previous step.
 
**Example Script**

```ruby
#!/usr/bin/env ruby

require "advance"
include Advance

ensure_bin_on_path # ensures the directory for this script is on
                   # the path so that related scripts can be referenced
                   # without paths

single :unzip_7z_raw_data_file, "7z x {previous_file}" # uses 7z to inflate a file in the current dir
single :split_files, "split -l 10000 -a 3 {previous_file} gps_data_" # split the file
multi :add_local_time, "cat {file_path} | add_local_time.rb timestamp local_time US/Pacific > {file}" # adds a local_time column to a csv
```

**Running Your Script**

When running your pipeline, it is helpful to have a directory with the single, initial file. 

1. Move to your data directory with your single initial file.
2. invoke your script from there.

## Contributing

We ♥️ contributions!

Found a bug? Ideally submit a pull request. And if that's not possible, make a bug report.

Did you create a data transformation script? Please consider adding it to the 
script collection in Advance by submitting a pull request.

Do you find the Advance documentation lacking? Please help us improve it. 

Can you translate the Advance documentation to your language? 

Bug reports and pull requests are welcome on GitHub at https://github.com/doctorjane/advance.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
