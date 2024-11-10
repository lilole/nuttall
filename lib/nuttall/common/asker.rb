# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "readline"

module Nuttall
module Common
  module Asker
    class AskerClass
      attr_reader :prompt, :target_hash, :target_key, :default_last, :nil_blank, :pass_blank, :last

      def initialize(prompt, target_hash, target_key, default_last, nil_blank, pass_blank)
        @prompt       = prompt.dup
        @target_hash  = target_hash
        @target_key   = target_key
        @default_last = default_last && user_target?
        @nil_blank    = nil_blank
        @pass_blank   = pass_blank || ! user_target?
      end

      def run
        set_prompt
        input = get_input

        if default_last
          if    input == "-" then input = ""
          elsif input == ""  then input = last
          end
        end

        input = nil if nil_blank && blank?(input)

        if user_target? && (pass_blank || size?(input))
          target_set(input)
        end

        input
      end

      def target_get
        hash, key = target_leaf
        hash[key]
      end

      def target_set(value)
        hash, key = target_leaf
        hash[key] = value
      end

      def target_leaf
        if Array === target_key
          hash = target_hash.dig(*target_key[0..-2])
          key  = target_key.last
        else
          hash = target_hash
          key  = target_key
        end
        [hash, key]
      end

      def get_input
        prev_int_trap  = trap("INT", "IGNORE")
        prev_comp_proc = Readline.completion_proc
        Readline.completion_proc = ->(_token) { [] }
        begin
          Readline.readline(prompt, true)
        ensure
          Readline.completion_proc = prev_comp_proc
          String === prev_int_trap ? trap("INT", prev_int_trap) : trap("INT", &prev_int_trap)
        end
      end

      def set_prompt
        if default_last && user_target? && (@last = target_get)
          if blank?(last)
            @default_last = false
          else
            prompt << " [#{last}] (\"-\" clears)"
          end
        end
        prompt[-1] == " " or prompt << ": "
      end

      def user_target? = target_hash && target_key

      def blank?(obj) = ! obj || String === obj && obj.strip.empty?

      def size?(obj) = ! blank?(obj)
    end # AskerClass

    def ask(prompt, target_hash=nil, target_key=nil, default_last: true, nil_blank: true, pass_blank: false)
      AskerClass.new(prompt, target_hash, target_key, default_last, nil_blank, pass_blank).run
    end
  end
end
end
