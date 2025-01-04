# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "fileutils"
require "shellwords"

desc "(With no args) Run specs"
task default: %w[rspec]

desc "Do everything in order"
task all: %w[crystal rspec]

desc "Run specs"
task :rspec do
  system("bundle exec rspec")
end

desc "Build all Crystal components"
task :crystal do
  build_args = "" # TODO: Release vs debug, etc
  build_dir  = "#{__dir__}/built"
  FileUtils.mkdir_p(build_dir)

  %w[cr].each do |subdir|
    Dir.chdir(File.expand_path(subdir, __dir__)) do
      Dir.glob("src/*.cr").each do |src_file|
        exe_file = File.basename(src_file, ".cr")
        exe_path = "#{build_dir}/#{exe_file}"
        file_args = "#{src_file.shellescape} -o #{exe_path.shellescape}"
        $stdout << exe_path << "..."; $stdout.flush
        system("crystal build #{build_args} #{file_args}") or fail
        puts "OK."
      end
    end
  end
end
