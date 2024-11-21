# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Mixin
  module Bash
    ### Run `bash` with input as a script, and return an object with useful
      # details about the completed process. This is a souped-up version of the
      # `%x{}` operator.
      #
      # The return object has these attrs:
      #   exitcode => Integer exit code of the process.
      #   fail? => Boolean true iff the process exited abnormally.
      #   line => The last element of `lines`, maybe nil.
      #   lines => The captured stdout lines as an array of chomped strings.
      #   ok? => Boolean true iff the process exited normally.
      #   okout => If the process exited normally, this will be the `out` attr
      #       value, but if not this will be `nil`.
      #   out => Combined stdout/stderr output captured in a chomped String.
      #   stderr => Only stderr output captured in a chomped String.
      #   stdout => Only stdout output captured in a chomped String.
      #
      # Valid values for `opts` are:
      #   :echo => Also send all process stdout/stderr output to current $stdout.
      #   :errs => Also send all process stderr to current $stderr.
      #
      # Valid keys for `opts2` are:
      #   :echo => If truthy, also send all process stdout/stderr output to given
      #       value, if an IO, or to current $stdout.
      #   :errs => If truthy, also send all process stderr output to given
      #       value, if an IO, or to current $stderr.
      #
    def bash(script, *opts, **opts2)
      bad_opts = opts + opts2.keys - %i[echo errs]
      raise "Invalid opts: #{bad_opts}" if bad_opts.any?

      echo_to = opts2[:echo].then { |opt| (IO === opt) ? opt : (opt && $stdout) }
      errs_to = opts2[:errs].then { |opt| (IO === opt) ? opt : (opt && $stderr) }

      opts.each do |opt|
        opt == :echo and echo_to = $stdout
        opt == :errs and errs_to = $stderr
      end

      pipr_s, pipw_s = IO.pipe # Process's stdout redirect
      pipr_e, pipw_e = IO.pipe # Process's stderr redirect
      begin
        io_s, io_e, io_a = Array.new(3) { StringIO.new } # Capture stdout, stderr, stdout+stderr
        buff_s, buff_e = "".b, "".b # Buffers for stdout, stderr
        stile = Mutex.new

        start  = -> { spawn(["bash", "#{self.class.name}-bash"], "-c", script, out: pipw_s, err: pipw_e) }
        finish = ->(_) { pipw_s.close; pipw_e.close }

        bufwrt = ->(buff, io) do
          io.write(buff)
          errs_to.write(buff) if errs_to && io == io_e
          stile.synchronize do
            io_a.write(buff)
            echo_to.write(buff) if echo_to
          end
        end

        process  = Thread.new { Process::Status.wait(start[]).tap(&finish) }
        reader_s = Thread.new { bufwrt[buff_s, io_s] while pipr_s.read(256, buff_s) }
        reader_e = Thread.new { bufwrt[buff_e, io_e] while pipr_e.read(256, buff_e) }

        stat = process.join.value
        [reader_s, reader_e].each { _1.join }
      ensure
        [pipr_s, pipw_s, pipr_e, pipw_e].each { _1.close }
      end

      @bash_result ||= Struct.new(:exitcode, :fail?, :line, :lines, :ok?, :okout, :out, :stderr, :stdout)
      @bash_result.new.tap do |result|
        ok = stat.success?
        out = { a: io_a, s: io_s, e: io_e }.map { |k, io| io.rewind; [k, io.read.chomp] }.to_h

        result.send("fail?=", ! ok)
        result.send("ok?=",   ok)
        result.exitcode = stat.exitstatus
        result.lines    = out[:s].split("\n")
        result.line     = result.lines.last # Maybe nil
        result.okout    = ok ? out[:a] : nil
        result.out      = out[:a]
        result.stderr   = out[:e]
        result.stdout   = out[:s]
      end
    end
  end
end
end
