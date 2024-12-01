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

    attr_reader :config, :disk_key, :settings

    def initialize(config, disk_key)
      @config   = config
      @disk_key = disk_key
      @settings = config.user_file_settings
    end

    def run
      return if ! need_new_image?
      return if ! user_confirm
      prep_docker_dir
      begin
        docker_build
      ensure
        scrub_docker_dir
      end
      wipe_docker_dir
    end

    def need_new_image?
      run = bash("docker image ls --format=json #{docker_image_name.shellescape}")
      return true if run.fail?
      run.lines.each do |line|
        info = JSON.parse(line)
        if info["Tag"] == docker_image_tag
          puts "\nWARNING: Image for #{docker_image_tag.inspect} exists: OVERWRITING IT."
          break
        end
      end
      true
    end

    def user_confirm
      ask("About to build a new Docker image for id #{docker_image_tag.inspect}.\n\nAre you sure?", "Yn")
    end

    def prep_docker_dir
      defs_filename = File.basename(config.defaults_file)
      reset_docker_dir

      cp = ->(*paths) do
        paths[0..-2].each { FileUtils.cp_r(_1, paths[-1], preserve: true) }
      end

      cp[dir_subpaths(app_dir("docker")), docker_dir]
      cp[app_dir("exe"),                  docker_dir("app")]
      cp[app_dir("lib"),                  docker_dir("app")]
      cp[app_dir("VERSION"),              docker_dir("app")]
      cp[app_dir("Gemfile"),              docker_dir("app")]
      cp[app_dir("Gemfile.lock"),         docker_dir("app")]
      cp[config.user_file,                docker_dir("app", defs_filename)]

      if settings.policy.key.container
        key_file = docker_dir("disk_key")
        File.write(key_file, disk_key, opts: 0600)
        File.chmod(0400, key_file)
      end
    end

    def scrub_docker_dir
      FileUtils.rm_f(docker_dir("disk_key"))
    end

    def reset_docker_dir
      wipe_docker_dir
      FileUtils.mkdir_p(docker_dir,        mode: 0700)
      FileUtils.mkdir_p(docker_dir("app"), mode: 0700)
    end

    def wipe_docker_dir
      FileUtils.rm_rf(docker_dir)
    end

    def docker_build
      print "\nBuilding..."; $stdout.flush
      tag = "#{docker_image_name}:#{docker_image_tag}"
      run = bash("docker buildx build --tag #{tag.shellescape} #{docker_dir.shellescape}")
      if run.ok?
        puts "OK."
      else
        puts "\nError: #{run.out}"
      end
      run.ok?
    end

    def docker_image_name = "#{config.file_basename}/server"

    def docker_image_tag = settings.container.id

    def docker_dir(*subs)
      @docker_dir ||= File.join(Dir.tmpdir, settings.container.name)
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
