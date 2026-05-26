# frozen_string_literal: true
#
# Copyright 2024-2026 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Extensions
  module Hash
    def self.apply
      @applied ||= !! ::Hash.include(Overlay)
    end

    module Overlay
      def self.recurse(obj)
        if    obj.respond_to?(:each_pair) then pairs = obj.each_pair
        elsif obj.respond_to?(:each)      then pairs = (0...obj.size).zip(obj)
        else  return [nil]
        end
        pairs.map do |k, v|
          recurse(v).map { |path| [k] << path }
        end.flatten(1)
      end

      def self.leaf_paths(object)
        recurse(object).map do |tups|
          tups.flatten[0..-2]
        end.sort do |a, b|
          cols = [a.size, b.size].min
          col_ranks = (0...cols).map { |c| (a[c] <=> b[c]) * 2**(cols - c - 1) }

          col_ranks.sum
        end
      end

      ## Soft merge another Hash- or Array-like object into `self`. This simply
       # means that any keys not present in `self` will be copied over from the
       # other object. Nested Hash- and Array-like objects are handled
       # recursively. Returns `self`.
       #
      def overlay(other)
        seen = Set[]
        Overlay.leaf_paths(other).each do |path|
          max_n = path.size - 1
          (0..max_n).each do |n|
            idxs = path[0..n]
            next if seen.member?(idxs)
            seen << idxs
            preleaf_idxs = idxs[0..-2]
            leaf_idx     = idxs[-1]
            target       = self.dig2(*preleaf_idxs)
            source       = other.dig2(*preleaf_idxs)
            value        = source[leaf_idx]
            target[leaf_idx] ||= (n < max_n) ? value.class.new : value
          end
        end
        self
      end
    end # Overlay
  end
end
end
