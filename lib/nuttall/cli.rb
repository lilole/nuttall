# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  class Cli
    include Mixin::Argie

    def self.usage(message=nil, exit_code=1)
      prog = "nuttall"
      $stderr << <<~END

        Description:
          #{prog} v#{Nuttall::VERSION}
          Main management tool for Nuttall logging systems.

        Message:
          #{message || "Online help."}

        Usage:
          #{prog} clean {exports}
          #{prog} config {name}
          #{prog} create
          #{prog} start
          #{prog} status
          #{prog} stop

        Where:
          clean => Transfer old data out of the service's disk space and remove it.

          config => Check or modify config params for a service.

          create => Create a new service on the current machine.

          start => Start service(s) on the current machine.

          status => Check status of service(s) on the current machine.

          stop => Stop service(s) on the current machine.

      END
      exit(exit_code) if exit_code && exit_code >= 0
    end

    attr_reader :args, :config

    def initialize(args)
      @args = args
      @config = Config.new
    end

    def run
      parse_args
      Core.new(config).run
      true
    rescue => e
      $stderr << e.full_message
      false
    end

    def parse_args
      argie(args) do |arg|
        if arg.option?
          arg.option?(%w[h ? help]) { Cli.usage }
          Cli.usage("Invalid option: #{arg.value}") if arg.unused?
        else
          arg.is?(valid_ops) { config.add_operation(arg.value) }
          Cli.usage("Invalid arg: #{arg.value}") if arg.unused?
        end
      end
      Cli.usage("At least 1 operation is required.") if config.operations.empty?
    end

    def valid_ops = Config.valid_operations
  end
end
