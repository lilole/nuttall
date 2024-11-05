# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  class Core
    attr_reader :config

    def initialize(config)
      @config = config
    end

    def run
      config.operations.each do |op|
        case op
        when "create" then Op::Create.new(config).run
        when "start"  then raise NotImplementedError
        when "status" then raise NotImplementedError
        when "stop"   then raise NotImplementedError
        end
      end
    end
  end
end
