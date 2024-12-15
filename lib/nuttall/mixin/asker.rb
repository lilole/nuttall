# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "io/console"
require "reline"

module Nuttall
module Mixin
  module Asker
    ### Support prompting user for an input value.
      # Features:
      #   - Line editing, with history of previous inputs.
      #   - Multi-line notes below the prompt for user guidance.
      #   - Editing preloaded values stored in a hash.
      #   - Using one or more "-" chars to cancel.
      #
    class AskValueClass
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
    end # AskValueClass

    ### Support prompting user for confirmation before continuing.
      # The `choices` may be any string of typable characters, with a single
      # uppercase to be the default if user presses Enter.
      #
      # If the choice is "q", then exit immediately.
      # If the choice is "y" or "n", then return Boolean.
      # Any other choice returns the character.
      # Ctrl-C is treated like "q".
      #
    class AskConfirmClass
      def self.run(prompt, choices)
        def_reply = choices.gsub(/[^A-Z]+/, "")
        raise "Only 1 uppercase is allowed: #{choices.inspect}" if def_reply.size > 1

        puts ""
        begin
          print "#{prompt} [#{choices}] "; $stdout.flush

          begin
            reply = $stdin.getch(intr: true).chomp
          rescue SignalException => e
            if e.signo == 2 # SIGINT
              puts "^C"
              lreply = "q"
              break
            end
          end
          reply = def_reply if reply.empty? && ! def_reply.empty?
          lreply = reply.downcase

          puts lreply
        end until lreply =~ /^[#{choices.downcase}]$/

        exit if lreply == "q"
        %w[y n].member?(lreply) ? lreply == "y" : reply
      end
    end # AskConfirmClass

    def ask(prompt, choices_or_target_hash, *args, **kargs)
      choices_or_target_hash.then do |arg1|
        if String === arg1
          choices = arg1
          AskConfirmClass.run(prompt, choices)

        elsif arg1.nil? || arg1.respond_to?(:each_pair)
          raise "Invalid extra args after target_key: #{args[1..-1].inspect}" if args.size > 1
          def_kargs = { default_last: true, nil_blank: true, notes: nil, pass_blank: false }
          bad_kargs = kargs.keys - def_kargs.keys
          raise "Invalid keyword args: #{bad_kargs.inspect}" if bad_kargs.any?

          target_hash = arg1
          target_key  = args[0]
          kargs       = def_kargs.merge(kargs)
          AskValueClass.new(prompt, target_hash, target_key,
            kargs[:default_last], kargs[:nil_blank], kargs[:pass_blank], kargs[:notes]
          ).run

        else
          raise "Invalid choices_or_target_hash: #{arg1.inspect}"
        end
      end
    end
  end
end
end
