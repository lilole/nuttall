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
      ::Object.include Dig2
      ::Object.include FalseyTruthy
      ::Object.include Overlay
      ::Object.include Visit
    end

    # Order matters, e.g. Visit must be defined before DeepToH

    module AsStruct
      ### Convert `self` if it is Hash-like, and any Hash-like elements in `self`,
        # into Struct objects, so that name keys can be accessed as method names.
        # This has a few advantages, such as (a) the code is easier to read, and
        # (b) typos in entry names will raise, and (c) entry access is faster than
        # OpenStruct.
        #
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
      ### Recursively visit each entry in `self` if it is Hash- or Array-like.
        # The given block will receive 3 args: (1) the "parent" object of the
        # entry, (2) the index or key of the entry, and (3) the value of the
        # entry. These 3 args allow the block to change any aspect of the entry,
        # including its key, and the block may even remove it.
        # A copy of `self` is returned if any recursion occurs.
        #
      def visit(&block)
        if    respond_to?(:each_pair) then pairs = each_pair.to_a
        elsif respond_to?(:each)      then pairs = (0...size).zip(self)
        else  return self
        end
        dup.tap do |self2|
          pairs.each { |k, v| block[self2, k, v.visit(&block)] }
        end
      end
    end # Visit

    module DeepToH
      include Visit

      ### Recursively call `to_h` on `self` and on entries within `self`.
        #
      def deep_to_h
        to_h.visit { |parent, k, v| parent[k] = v.to_h if v != nil && v.respond_to?(:to_h) }
      end
    end # DeepToH

    module Dig2
      ### A smarter `dig()`, which simply returns `self` if there are no args.
        #
      def dig2(*indexes)
        indexes.empty? ? self : dig(*indexes)
      end
    end # Dig2

    ### Add `#falsey?` and `#truthy?` methods that handle String values with
      # variations of "true" or "yes".
      #
    module FalseyTruthy
      @@truthy_regex = /\At(rue)?\z|\Ay(es)?\z/i

      def falsey? = ! truthy?

      def truthy? = (String === self) ? @@truthy_regex.match?(self.strip) : !! self
    end # FalseyTruthy

    module Overlay
      include Dig2

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

      ### Soft merge another Hash- or Array-like object into `self`. This simply
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
