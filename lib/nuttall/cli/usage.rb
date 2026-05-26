# frozen_string_literal: true
#
# Copyright 2024-2026 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

module Nuttall
module Cli
  module Usage
    def usage(message=nil, exit_code=1)
      prog = "nuttall"
      $stderr << <<~END

        Description:
          #{prog} #{Nuttall::VERSION}
          Main management tool for Nuttall logging systems.

        Message:
          #{message || "Online help."}

        Usage:
          #{prog} clean {exports}
          #{prog} config {name}
          #{prog} create
          #{prog} start
          #{prog} status
          #{prog} stop

        Where:
          clean => Transfer old data out of the service's disk space and remove it.

          config => Check or modify config params for a service.

          create => Create a new service on the current machine.

          start => Start service(s) on the current machine.

          status => Check status of service(s) on the current machine.

          stop => Stop service(s) on the current machine.

      END
      exit(exit_code) if exit_code && exit_code >= 0
    end
  end
end
end
