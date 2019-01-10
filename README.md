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

Advance scripts are easy to understand. They are ruby scripts, 
composed of a series of function calls that invoke your scripts
or commands to transform your data. Each step is composed of a
step processing type function, followed by a 
slug for the step, followed by the command or script. For example:

```ruby
single :unzip_7z_raw_data_file, "7z x {previous_file}"
single :split_files, "split -l 10000 -a 3 {previous_file} gps_data_"
multi :add_local_time, "cat {file_path} | add_local_time.rb timestamp local_time US/Pacific > {file}"
# ...
```

The step processing functions are `single` and `multi`. `Single` applies the command
to the last output, which should be a single file. `Multi` speeds processing of multiple
files by doing working in parallel (via the [TeamEffort gem][1]).

[1]: https://rubygems.org/gems/team_effort

> _[Advance][2]: To help the progress of (something); to further._

[2]: https://en.wiktionary.org/wiki/advance

## Installation

Advance is meant to augment a standalone ruby script. The advance gem needs to be 
available to your instance of ruby. Here are 2 techniques to make Advance available
to your script:

 * simply install the gem:

    $ gem install advance
    
 * install [bundler][3], and add this ruby snippet to the beginning of your script:
 
[3]: https://rubygems.org/gems/bundler
 
```ruby
    #!/usr/bin/env ruby
    require "bundler/inline"
    
    gemfile do
      source "https://rubygems.org"
      gem "advance"
    end
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
of the script. Advance also adds the path of your script to PATH so that you can 
invoke scripts in the same directory as your main script without specifying 
the full path of the script. Of course, you can invoke any script if the path
to the script is fully specified or the path is already on PATH.

**Specifying Script Input and Output**

Since your command is transforming data, you need a way to specify the input 
file or directory and the output file name. Advance provides a few tokens 
that can be inserted in the command string for this purpose:

 * **{previous_file}** indicates the output file from the previous step when
   the output of the previous step was a single output file. It is also used
   to indicate the first file to be used and it finds that file in the current 
   working dir.
 * **{file_path}** indicates an output file from the previous step when the
   previous step generated multiple output files and the current step is a 
   `multi` step.
 * **{file}** indicates an output file name, which is the basename from 
   {file_path}. Commands often process multiple files from previous steps, 
   generating multiple output files. Those output files are placed in the
   step directory.
 * **{previous_dir}** indicates the directory a previous step.
 
**Example Script**

```ruby
#!/usr/bin/env ruby
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "advance"
end

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/doctorjane/advance.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
