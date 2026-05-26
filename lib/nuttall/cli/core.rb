# frozen_string_literal: true
#
# Copyright 2024-2026 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Cli
  class Core
    include Nuttall::Cli::Usage
    Config = Nuttall::Config

    attr_ro :args, :config

    def initialize(args)
      self.args = args
      self.config = Config.new
    end

    def run
      parse_args
      Nuttall::Core.new(config).run
      true
    rescue => e
      $stderr << e.full_message
      false
    end

    def parse_args
      Ulse.argie(args) do |arg|
        if arg.option?
          arg.option?(%w[h ? help]) { usage }
          usage("Invalid option: #{arg.value}") if arg.unused?
        else
          arg.is?(valid_ops) { config.add_operation(arg.value) }
          usage("Invalid arg: #{arg.value}") if arg.unused?
        end
      end
      usage("At least 1 operation is required.") if config.operations.empty?
    end

    def valid_ops = Config.valid_operations
  end
end
end
