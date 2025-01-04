# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Extensions
  module Numeric
    def self.apply
      ::Numeric.include Commafy
    end

    module Commafy
      def self.commafy(n)
        n.to_s.reverse.gsub(/(\d{3})(?=\d)(?!\d*\.)/, "\\1,").reverse
      end

      def commafy
        if Complex === self
          "%s+%si" % rect.map { Commafy.commafy(_1) }
        elsif Rational === self
          "(%s/%s)" % [Commafy.commafy(numerator), Commafy.commafy(denominator)]
        else
          Commafy.commafy(Integer === self ? self : to_f)
        end
      end
    end # Commafy
  end
end
end
