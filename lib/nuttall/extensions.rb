# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
  module Extensions
    def self.apply
      @applied ||= begin
        ::Ulse::Ext::Object::AsGrouping.apply
        ::Ulse::Ext::Object::Dig2.apply
        ::Ulse::Ext::Object::Transform.apply
        ::Ulse::Ext::Object::TruthyFalsey.apply
        ::Ulse::Ext::Numeric::Commafy.apply
        ::Ulse::Ext::String::Ellipt.apply

        ::Nuttall::Extensions::Hash.apply
      end
    end
  end
end
