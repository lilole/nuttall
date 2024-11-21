# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "reline"

module Nuttall
module Mixin
  module Asker
    class AskerClass
      attr_reader :prompt, :target_hash, :target_key, :default_last, :nil_blank, :pass_blank, :last, :notes

      def initialize(prompt, target_hash, target_key, default_last, nil_blank, pass_blank, notes)
        @prompt       = prompt.dup
        @target_hash  = target_hash
        @target_key   = target_key
        @default_last = default_last && user_target?
        @nil_blank    = nil_blank
        @pass_blank   = pass_blank || ! user_target?
        @notes        = notes
      end

      def run
        set_prompt
        input = input_orig = get_input

        if default_last
          if    input =~ /^-+$/ then input = ""
          elsif input == ""     then input = last
          end
        end

        input = nil if nil_blank && blank?(input)

        if user_target? && (pass_blank || size?(input))
          target_set(input)
        end

        input_orig
      end

      def target_get
        hash, key = target_leaf
        hash[key].to_s
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
        Reline.completion_proc = ->(_token) { [] }
        Reline.emacs_editing_mode
        Reline.pre_input_hook = size?(last) ? -> { Reline.insert_text(last.to_s) } : nil
        begin
          show_notes
          Reline.readline(prompt, true)
        rescue SignalException => e
          print "^C" if e.signo == 2 # SIGINT
          nil
        ensure
          notes.lines.size.times { puts "" }
        end
      end

      def show_notes
        return if blank?(notes)
        lines = notes.rstrip.lines
        print "\n  #{lines.join("  ")}\r"
        lines.size.times { print "\e[A" }
      end

      def set_prompt
        if default_last && user_target? && (@last = target_get)
          @default_last = ! blank?(last)
        end
        if prompt =~ /^([\r\n\t]+)/
          print $~[1]
          prompt[0 ... $~[1].size] = ""
        end
        prompt.gsub!(/[\r\n\t]+/, " ")
        prompt[-1] == " " or prompt << ": "
      end

      def user_target? = target_hash && target_key

      def blank?(obj) = ! obj || String === obj && obj.strip.empty?

      def size?(obj) = ! blank?(obj)
    end # AskerClass

    def ask(prompt, target_hash=nil, target_key=nil, notes: nil, default_last: true, nil_blank: true, pass_blank: false)
      AskerClass.new(prompt, target_hash, target_key, default_last, nil_blank, pass_blank, notes).run
    end
  end
end
end
