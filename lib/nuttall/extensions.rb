# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  module Extensions
    def self.apply
      ::Object.respond_to?(:as_struct) or ::Object.include Object::AsStruct
    end

    module Object
      module AsStruct
        def as_struct
          if respond_to?(:keys) && respond_to?(:values)
            Struct.new(*keys.map(&:to_sym)).new(*values.map(&:as_struct))
          elsif respond_to?(:map)
            map(&:as_struct)
          else
            self
          end
        end
      end
    end
  end
end
