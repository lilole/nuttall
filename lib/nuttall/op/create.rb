# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Op
  class Create
    include Common::Asker

    class SettingsAborted < RuntimeError; end

    attr_reader :config, :settings

    def initialize(config)
      @config = config
      @settings = config.user_file_settings
    end

    def run
      begin
        get_settings
        save_settings
      rescue SettingsAborted
        nil
      end
    end

    def get_settings
      puts(<<~END)

        Notes on text editing:
          - Ctrl-A and Ctrl-E go to beginning and end of line (Home/End keys may work).
          - Ctrl-U and Ctrl-K delete to beginning and end of line.
          - Enter a single dash "-" to go back.
          - Enter two dashes "--" to cancel all changes and exit.
      END

      stepi = -1
      while (step = steps[stepi += 1])
        input = step[] || "--"
        if    input == "-"  then stepi = [stepi - 2, -1].max
        elsif input == "--" then raise SettingsAborted
        end
      end
    end

    def save_settings
      puts "\n#{settings.inspect}"
    end

    def steps
      @steps ||= [
        -> do
          ask("\nWork area base dir", settings, %i[container workdir], notes: <<~END)
            - This must be on a filesystem with all necessary disk space.
            - The default value is a preferred path chosen on the filesystem of
              this host with the most free space.
          END
        end,

        -> do
          ask("\nContainer name", settings, %i[container name], notes: <<~END)
            - This must be unique within the current host.
            - If you're setting up a local network of Nuttalls, then this must be
              unique within the network.
            - The default value is a unique name on both this host and the local
              network.
          END
        end,

        -> do
          ask("\nStarting disk size", settings, %i[disk size start], notes: <<~END)
            - This is the initial size of the virtual disk of the Nuttall container.
            - Standard suffixes like "M", "MB", "G", "GB", etc are supported.
            - A suffix of "%" means percent of the current filesystem at this moment.
          END
        end,

        -> do
          ask("\nMax disk size", settings, %i[disk size max], notes: <<~END)
            - This is the max size of the virtual disk of the Nuttall container.
            - If the virtual disk size grows to this amount, it may start to fill up.
            - Standard suffixes like "M", "MB", "G", "GB", etc are supported.
            - A suffix of "%" means percent of the current filesystem at this moment.
          END
        end,

        -> do
          ask("\nDisk size increment", settings, %i[disk size increment], notes: <<~END)
            - As the virtual disk fills and grows from its starting size to its max
              size, this is the amount of each growth step.
            - Standard suffixes like "M", "MB", "G", "GB", etc are supported.
            - The "%" suffix is not supported here.
          END
        end,

        -> do
          ask("\nEncrypt the virtual disk", settings, %i[disk encrypt enable], notes: <<~END)
            - If "true" then the container's virtual disk will be encrypted with an
              auto generated key stored only inside the container.
            - This should usually be enabled unless you need the max possible disk
              speed, or if you are testing with non-production log data.
          END
        end,

        -> do
          ask("\nRetention for the index", settings, %i[policy retain index], notes: <<~END)
            - This is the max time log entries will remain in the live index and be
              searchable.
            - Suffixes like "hours", "h", "days", "d", "weeks", "w", "months", "mo"
              are supported.
          END
        end,

        -> do
          ask("\nRetention for exports", settings, %i[policy retain exports], notes: <<~END)
            - After log entries expire from the index, they are exported to zip files
              in the container's virtual disk.
            - This defines how long those exported files are kept.
            - Each exported file will be 1 day's worth of log entries.
          END
        end,

        -> do
          ask("\nDiscard unretained indexes if full", settings, %i[policy discard index], notes: <<~END)
            - If "true", and if the virtual disk is at max size and is full, then
              indexed log entries that are no longer retained will be removed instead
              of exported.
            - The recommended setting is "false".
          END
        end,

        -> do
          ask("\nDiscard exports if full", settings, %i[policy discard exports], notes: <<~END)
            - If "true", and if the virtual disk is at max size and is full, then
              the oldest exported log entry files will be removed.
            - The recommended setting is "true". But use "false" if you have stricter
              retention policies that require not removing anything. In this case,
              make sure you continually run "clean" to prevent disk full errors, or
              use a very big virtual disk.
          END
        end
      ]
    end
  end
end
end
