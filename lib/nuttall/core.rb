# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  class Core
    attr_reader :config

    def initialize(config)
      @config = config
      assert_root_user
      assert_system_cmds
    end

    def assert_root_user
      raise "You must be root to use this tool" if Process.uid != 0
    end

    def assert_system_cmds
      required = %w[bash docker lsblk]
      dirs = ENV["PATH"].split(":")
      exe = ->(dir, cmd) { File.executable?(File.join(dir, cmd)) }

      missing = required.map do |cmd|
        dirs.any? { |d| exe[d, cmd] } ? nil : cmd
      end.compact

      raise "Cannot find needed commands in PATH: #{missing}" if missing.any?
    end

    def run
      config.operations.each do |op|
        case op
        when "create" then Op::Create::Core.new(config).run
        when "start"  then raise NotImplementedError
        when "status" then raise NotImplementedError
        when "stop"   then raise NotImplementedError
        end
      end
    end
  end
end
