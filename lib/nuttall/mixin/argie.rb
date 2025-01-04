# frozen_string_literal: true
#
# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Mixin
  ### Full arg processing in a single method. Example usage:
    #   argie(args) do |arg|
    #     arg.option?(%w[help h ?]) { usage }
    #     arg.option?("base=", "b=", /^--(?<param>\d+)$/) { config[:base] = arg.value.to_i }
    #     arg.literal? do
    #       if    ! config[:input_file] then config[:input_file] = arg.value
    #       elsif ! config[:max]        then config[:max] = arg.value.to_i
    #       end
    #     end
    #     usage("Invalid arg: #{arg.raw.inspect}") if arg.unused?
    #   end
    #
  module Argie
    class ArgieWrapper
      attr_accessor :arg_proc, :args, :index, :is_option, :is_param, :last_match, :parse_options, :used

      def initialize(args, arg_proc)
        @args = args
        @arg_proc = arg_proc
        reset!
        main_loop
      end

      ### With no params, returns true if the current arg being processed is an option.
        # With params, attempt to match the arg and prep for processing the value in user code.
        #
        # Option args are long or short, and may or may not have a value arg associated.
        # For example, passing `%w[file= F=]` matches one of:
        #   `--file value`, `--file=value`, `-F value` or `-Fvalue`
        # Without the trailing `=`, there is no value, so `%w[file F]` would match:
        #   `--file`, `-F`, or `-xFy`.
        #
        # You can parse any option format by passing a regex of your own, and assign the value,
        # if any, to a `param` regex group label. For example, `/^--(?<param>[0-9]+)` would
        # match `--42` and assign the option value to "42".
        #
      def option?(*opts, &if_yes)
        if opts.empty? || ! is_option
          if_yes[] if if_yes && is_option
          return is_option
        end

        regex_ors = opts.flatten.map do |opt|
          next opt.to_s if Regexp === opt

          @is_param   = opt[-1] == "="
          last_ch_idx = is_param ? -2 : -1
          single      = opt.size == -last_ch_idx
          opt         = Regexp.escape(opt[0..last_ch_idx])

          if is_param
            if single
              "^-[^-]*#{opt}(?<param>.+)?$"
            else
              "^--#{opt}(=(?<param>.+))?$"
            end
          else
            if single
              "^-[^-]*#{opt}"
            else
              "^--#{opt}$"
            end
          end
        end

        opt_re = Regexp.new(regex_ors.join("|"))

        @last_match = opt_re.match(args[index])
        used! if last_match
        if_yes && last_match ? if_yes[] : !! last_match
      end

      ### Whether option or literal, attempt to match the current arg being processed.
        # Params are any lists of strings, to match exactly, or regexes.
        #
      def is?(*values, &if_yes)
        current_val = args[index].to_s
        values.flatten.any? do |user_val|
          if   Regexp === user_val then user_val.match?(current_val)
          else user_val.to_s == current_val
          end
        end.tap do |matched|
          used! if matched
          if_yes[] if if_yes && matched
        end
      end

      ### Return a group of args relative to the current arg being processed, and advance
        # processing to the next arg following the group.
        #
      def consume(range)
        rbegin = index + range.first
        rend   = index + range.last + (range.last < 0 ? args.size : 0) - (range.exclude_end? ? 1 : 0)
        @index = rend
        used!
        args[rbegin..rend]
      end

      def reset!(index=-1)
        @index = index
        self
      end

      def literal?(&if_yes)
        (! is_option).tap do |yes|
          if_yes[] if yes && if_yes
        end
      end

      def value
        if is_option && is_param
          last_match && last_match[:param] || next!
        else
          raw
        end
      end

      def next!          = (@index += 1; raw)
      def parse_options? = !! parse_options
      def raw            = (used!; args[index])
      def unused?        = ! used
      def unused!        = (@used = false; self)
      def used?          = used
      def used!          = (@used = true; self)

    private

      def main_loop
        @parse_options = true

        while (@index += 1) < args.size
          if parse_options? && raw == "--"
            @parse_options = false
            next
          end
          @is_option = parse_options? && raw[0] == "-"
          unused!
          arg_proc[self]
        end

        self
      end
    end # ArgieWrapper

    def argie(args, &arg_processor)
      ArgieWrapper.new(args, arg_processor)
    end
  end
end
end
