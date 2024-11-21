# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Extensions
  module Object
    def self.apply
      ::Object.include AsStruct
      ::Object.include DeepToH
      ::Object.include FalseyTruthy
      ::Object.include Visit
    end

    # Order matters, e.g. Visit must be defined before DeepToH

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
    end # AsStruct

    module Visit
      def visit(&block)
        if    respond_to?(:each_pair) then pairs = each_pair.to_a
        elsif respond_to?(:each)      then pairs = each.with_index.map { |v, k| [k, v] }
        else  return self
        end
        dup.tap { |self2| pairs.each { |k, v| block[self2, k, v.visit(&block)] } }
      end
    end # Visit

    module DeepToH
      include Visit

      def deep_to_h
        to_h.visit { |parent, k, v| parent[k] = v.to_h if v != nil && v.respond_to?(:to_h) }
      end
    end # DeepToH

    module FalseyTruthy
      @@truthy_regex = /\At(rue)?\z|\Ay(es)?\z/i

      def falsey? = ! truthy?

      def truthy? = (String === self) ? @@truthy_regex.match?(self.strip) : !! self
    end # FalseyTruthy
  end
end
end
