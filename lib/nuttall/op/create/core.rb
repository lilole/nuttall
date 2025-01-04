# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "fileutils"

module Nuttall
module Op
module Create
  class Core
    include Nuttall::Mixin::Asker
    include Nuttall::Mixin::FsInfo
    include Nuttall::Mixin::SecureKey

    class SettingsAborted < RuntimeError; end

    attr_reader :config, :encryption_key, :settings

    def initialize(config)
      @config = config
      @settings = config.user_file_settings
    end

    def run
      begin
        get_settings
      rescue SettingsAborted
        return
      end
      save_defaults_file
      prep_workdir
      save_settings
      Nuttall::Container::Builder.new(config, encryption_key).run
    end

    def get_settings
      puts(<<~END)

        Notes on text editing:
          - Ctrl-A and Ctrl-E go to beginning and end of line (Home/End keys may work).
          - Ctrl-U and Ctrl-K delete to beginning and end of line.
          - Enter a single dash "-" to go back.
          - Enter two dashes "--" to cancel all changes and exit.
      END

      stepi = 0
      while (step = steps.find { _1.index == stepi })
        input = step.work[] || "--"
        if    input == "--"          then raise SettingsAborted
        elsif input == "-"           then stepi = [stepi - 2, -1].max
        elsif ! step.validate[input] then stepi -= 1
        end
        stepi += 1
      end
    end

    def save_defaults_file
      ignore_changed = [
        [[:container], :id],
        [[:container], :name],
        [[:container], :workdir],
      ]
      reset_ignored_values(ignore_changed)

      defaults = config.defaults_file
      if ! File.exist?(defaults) || File.read(defaults) != config.user_file_text
        config.save_user_file
        puts "\nSaved default values to #{defaults.inspect}."
      end

      restore_ignored_values(ignore_changed)
    end

    def reset_ignored_values(ignore_changed)
      orig_settings = config.load_user_file(ignore_err: true)
      ignore_changed.each do |tuple|
        dig_args, key = tuple[0, 2]
        tuple << settings.dig(*dig_args)[key]
        settings.dig(*dig_args)[key] = orig_settings.dig(*dig_args)[key]
      end
    end

    def restore_ignored_values(ignore_changed)
      ignore_changed.each do |tuple|
        dig_args, key, saved_value = tuple[0, 3]
        settings.dig(*dig_args)[key] = saved_value
      end
    end

    def prep_workdir
      FileUtils.mkdir_p(container_dir, mode: 0700)
    end

    def container_dir = File.join(settings.container.workdir, config.file_basename, settings.container.name)

    def save_settings
      enforce_parsed_settings
      config.user_file = File.join(config.defaults_file_dir, "#{settings.container.name}.yml")
      config.save_user_file
      config.user_file = File.join(container_dir, "settings.yml")
      config.save_user_file
      puts(<<~END)

        Saved settings to #{config.user_file.inspect}.

        Use the "config" subcommand to update settings later if needed.
      END
    end

    def enforce_parsed_settings
      [settings.disk, settings.policy, settings.container].then do |d, p, c|
        d.size.start     = config.parse_disk_size(d.size.start,     c.workdir)
        d.size.max       = config.parse_disk_size(d.size.max,       c.workdir)
        d.size.increment = config.parse_disk_size(d.size.increment, c.workdir)
        p.retain.index   = config.parse_duration(p.retain.index)
        p.retain.exports = config.parse_duration(p.retain.exports)
      end
    end

    def writable_head(dir)
      dir = File.expand_path(dir)
      loop do
        break dir if File.writable?(dir)
        break nil if dir == "/"
        dir = File.dirname(dir)
      end
    end

    def steps
      @steps ||= [].tap do |steps|
        steps << Step.new.tap do |step|
          step.index = 0

          step.work = -> do
            settings.container.workdir ||= config.default_workdir
            ask("\nWork area base dir", settings, %i[container workdir], notes: <<~END)
              - This must be on a filesystem with all necessary disk space.
              - The default value is a preferred path chosen on the filesystem of
                this host with the most free space.
            END
          end

          step.validate = ->(input) do
            full_path = File.expand_path(input)

            if ! Dir.exist?(full_path)
              if ! writable_head(full_path)
                puts "\nThis dir cannot be created."
                return false
              end

              reply = ask("\nThis dir does not exist. Do you want to create it? ")
              return reply.truthy?

            elsif ! File.writable?(full_path)
              puts "\nThis dir is not writable."
              return false
            end

            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 1

          step.work = -> do
            settings.container.id   ||= config.config_id
            settings.container.name ||= config.default_name
            ask("\nContainer name", settings, %i[container name], notes: <<~END)
              - This must be unique within the current host.
              - If you're setting up a local network of Nuttalls, then this must be
                unique within the network.
              - The default value is a unique name on both this host and the local
                network.
            END
          end

          step.validate = ->(input) do
            bad = input.gsub(/[-\w]+/, "")
            if ! bad.empty?
              puts "\nThis name has invalid characters: #{bad.chars.uniq.inspect}"
              return false
            end
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 2

          step.work = -> do
            ask("\nStarting disk size", settings, %i[disk size start], notes: <<~END)
              - This is the initial size of the virtual disk of the Nuttall container.
              - Standard suffixes like "K" & "KiB" for 1024s or "KB" for 1000s are supported.
              - A suffix of "%" means percent of the work dir's total filesystem.
            END
          end

          step.validate = ->(input) do
            fs_dir = writable_head(settings.container.workdir)
            if ! (size = config.parse_disk_size(input, fs_dir))
              puts "\nCannot parse this disk size."
              return false
            elsif size < 1_000_000
              puts "\nInvalid size: Cannot be less than 1 MB."
              return false
            elsif size > (total = fs_info(fs_dir)[:fs_free])
              puts "\nInvalid size: Cannot be more than free bytes: #{total}"
              return false
            end
            puts "\nStart size will be #{size.commafy} bytes."
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 3

          step.work = -> do
            ask("\nMax disk size", settings, %i[disk size max], notes: <<~END)
              - This is the max size of the virtual disk of the Nuttall container.
              - If the virtual disk size grows to this value, it may start to fill up.
              - Standard suffixes like "K" & "KiB" for 1024s or "KB" for 1000s are supported.
              - A suffix of "%" means percent of the work dir's total filesystem.
            END
          end

          step.validate = ->(input) do
            fs_dir = writable_head(settings.container.workdir)
            if ! (size = config.parse_disk_size(input, fs_dir))
              puts "\nCannot parse this disk size."
              return false
            elsif size < config.parse_disk_size(settings.disk.size.start, fs_dir)
              puts "\nInvalid size: Cannot be less than starting size: #{settings.disk.size.start}"
              return false
            elsif size > (total = fs_info(fs_dir)[:fs_free])
              puts "\nInvalid size: Cannot be more than free bytes: #{total}"
              return false
            end
            puts "\nMax size will be #{size.commafy} bytes."
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 4

          step.work = -> do
            ask("\nDisk size increment", settings, %i[disk size increment], notes: <<~END)
              - As the virtual disk fills and grows from its starting size to its max
                size, this is the amount of each growth step.
              - Standard suffixes like "K" & "KiB" for 1024s or "KB" for 1000s are supported.
              - The "%" suffix is not supported here.
            END
          end

          step.validate = ->(input) do
            fs_dir = writable_head(settings.container.workdir)
            start_sz = config.parse_disk_size(settings.disk.size.start, fs_dir)
            if ! (size = config.parse_disk_size(input))
              puts "\nCannot parse this disk size."
              return false
            elsif size < 1_000_000
              puts "\nSize is invalid: Cannot be less than 1 MB."
              return false
            elsif size > (total = fs_info(fs_dir)[:fs_free] - start_sz)
              puts "\nInvalid size: Cannot be more than free bytes minus start size: #{total}"
              return false
            end
            puts "\nSize will increase by #{size.commafy} bytes."
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 5

          step.work = -> do
            ask("\nEncrypt the virtual disk", settings, %i[disk encrypt enable], notes: <<~END)
              - If "true" then the container's virtual disk will be encrypted with an
                auto generated key.
              - This should be enabled unless you are more concerned about disk speed
                than security, or if you are testing with non-production log data.
            END
          end

          step.validate = ->(input) do
            if ! %w[true t false f].member?(input)
              puts "\nOnly \"t[rue]\" or \"f[alse]\" is valid."
              return false
            end
            settings.disk.encrypt.enable = input.truthy?
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 6

          step.work = -> do
            ask("\nRetention for the index", settings, %i[policy retain index], notes: <<~END)
              - This is the max time log entries will remain in the live index and be
                searchable.
              - Suffixes like "hours", "h", "days", "d", "weeks", "w", "months", "mo"
                are supported. A value without a suffix is in seconds.
            END
          end

          step.validate = ->(input) do
            if ! config.parse_duration(input)
              puts "\nCannot parse this duration."
              return false
            end
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 7

          step.work = -> do
            ask("\nRetention for exports", settings, %i[policy retain exports], notes: <<~END)
              - After log entries expire from the index, they are exported to zip files
                in the container's virtual disk.
              - This defines how long those exported files are kept.
              - Suffixes like "hours", "h", "days", "d", "weeks", "w", "months", "mo"
                are supported. A value without a suffix is in seconds.
              - Each exported file will be 1 day's worth of log entries.
              - Running the "clean" subcommand will copy and remove exports.
            END
          end

          step.validate = ->(input) do
            if ! config.parse_duration(input)
              puts "\nCannot parse this duration."
              return false
            end
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 8

          step.work = -> do
            ask("\nDiscard unretained indexes if full", settings, %i[policy discard index], notes: <<~END)
              - If "true", and if the virtual disk is at max size and is full, then
                indexed log entries that are no longer retained will be removed instead
                of exported.
              - The recommended setting is "false".
            END
          end

          step.validate = ->(input) do
            if ! %w[true t false f].member?(input)
              puts "\nOnly \"t[rue]\" or \"f[alse]\" is valid."
              return false
            end
            settings.policy.discard.index = input.truthy?
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 9

          step.work = -> do
            ask("\nDiscard exports if full", settings, %i[policy discard exports], notes: <<~END)
              - If "true", and if the virtual disk is at max size and is full, then
                the oldest exported log entry files will be removed.
              - The recommended setting is "true". But use "false" if you have stricter
                retention policies that require not removing anything. In this case,
                make sure you continually run "clean" to prevent disk full errors, or
                use a very big virtual disk.
            END
          end

          step.validate = ->(input) do
            if ! %w[true t false f].member?(input)
              puts "\nOnly \"t[rue]\" or \"f[alse]\" is valid."
              return false
            end
            settings.policy.discard.exports = input.truthy?
            true
          end
        end

        steps << Step.new.tap do |step|
          step.index = 10

          step.work = -> do
            ask("\nStore encryption key in container", settings, %i[policy key container], notes: <<~END)
              - If your server has multiple people who can login as root or run docker,
                then this should probably be "false".
              - If "false", then note:
                - The generated key will be displayed temporarily, and you MUST copy/paste
                  it into a secure storage manager of your choice, such as KeePass,
                  RoboForm, AWS SecretsManager, etc.
                - This key must be pasted into the terminal every time the container
                  starts up. Or, secure storage manager integration may be made
                  available for your environment.
              - If "true", then the generated key will be saved for root only inside the
                container. This is secure if your root credentials and docker command
                privileges are locked down to you and very few very trusted users.
            END
          end

          step.validate = ->(input) do
            if ! %w[true t false f].member?(input)
              puts "\nOnly \"t[rue]\" or \"f[alse]\" is valid."
              return false
            end
            use_container = input.truthy?
            settings.policy.key.container = use_container

            key = @encryption_key = SecureKey.generate_typable
            if ! use_container
              ask("About to display encryption key for this container. Are you sure?", "Yn") or return false
              puts "\nCopy/paste this key into your secure storage manager."
              puts "Press Enter when done, and the key will be erased from the terminal:"
              puts "\n#{key}"; $stdout.flush
              $stdin.gets
              puts "\e[A" * 2 + " " * key.size
            end

            true
          end
        end
      end
    end
  end
end
end
end
