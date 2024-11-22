# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "fileutils"
require "json"
require "shellwords"

module Nuttall
module Container
  class Builder
    include Mixin::Asker
    include Mixin::Bash

    attr_reader :config, :settings

    def initialize(config)
      @config = config
      @settings = config.user_file_settings
    end

    def run
      return if ! need_new_image?
      return if ! user_confirm
      prep_docker_dir
      docker_build
    end

    def need_new_image?
      run = bash("docker image ls --format=json #{docker_image_name.shellescape}")
      return true if run.fail?
      info = JSON.parse(run.stdout)
      if info["Tag"] == Nuttall::VERSION
        puts "\nWarning: Image #{docker_image_name}:#{Nuttall::VERSION} exists: Overwriting it."
      end
      true
    end

    def user_confirm
      ask("About to build a new Docker image for version #{Nuttall::VERSION}. Are you sure?", "Yn")
    end

    def prep_docker_dir
      FileUtils.then do |fs|
        fs.rm_rf(docker_dir)
        fs.mkdir_p(docker_dir("app"))
        fs.cp_r(dir_subpaths(app_dir("docker")), docker_dir)
        fs.cp_r(app_dir("exe"),                  docker_dir("app"))
        fs.cp_r(app_dir("lib"),                  docker_dir("app"))
        fs.cp_r(app_dir("VERSION"),              docker_dir("app"))
      end
    end

    def docker_build
      print "\nBuilding..."; $stdout.flush
      tag = "#{docker_image_name}:#{Nuttall::VERSION}"
      run = bash("docker buildx build --tag #{tag.shellescape} #{docker_dir.shellescape}")
      if run.ok?
        puts "OK."
      else
        puts "\nError: #{run.out}"
      end
      run.ok?
    end

    def docker_image_name = "#{config.file_basename}/server"

    def docker_dir(*subs)
      @docker_dir ||= File.join(Dir.tmpdir, config.file_basename)
      to_path(@docker_dir, *subs)
    end

    def app_dir(*subs)
      to_path(Nuttall::APP_DIR, *subs)
    end

    def to_path(*parts)
      File.join(File.expand_path(parts[0].to_s), *parts[1..-1].map(&:to_s))
    end

    def dir_subpaths(dir)
      dir = to_path(dir)
      excludes = %w[. ..].map { File.join(dir, _1) }
      Dir.glob("#{dir}/*", File::FNM_DOTMATCH) - excludes
    end
  end
end
end
