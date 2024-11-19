# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Op
module Create
  class Step
    def index=(value)
      raise ArgumentError, "Index must be an integer" unless Integer === value
      @index = value
    end

    def index
      raise "Index must be set" if @index.nil?
      @index
    end

    def validate=(value)
      raise ArgumentError, "Validate must be a proc with 1 argument" unless Proc === value && value.arity == 1
      @validate = value
    end

    def validate
      raise "Validate must be set" if @validate.nil?
      @validate
    end

    def work=(value)
      raise ArgumentError, "Work must be a proc" unless Proc === value
      @work = value
    end

    def work
      raise "Work must be set" if @work.nil?
      @work
    end
  end
end
end
end
