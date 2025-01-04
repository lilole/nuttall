# Copyright 2024-2025 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "http/server"
require "openssl"

module Nuttall
module Server
  class Core
    getter :config

    def initialize(config : Hash(Symbol, String))
      @config = config
      @enc_context = uninitialized OpenSSL::SSL::Context::Server
    end

    def run
      server = HTTP::Server.new do |context|
        context.response.content_type = "text/plain"
        context.response.print "Hello world at #{Time.local}!"
      end

      address = server.bind_tls("0.0.0.0", 8443, enc_context)
      puts "Listening on https://#{address}"
      server.listen
    end

    def enc_context
      @enc_context ||= begin
        OpenSSL::SSL::Context::Server.new.tap do |ctx|
          ctx.add_options(
            OpenSSL::SSL::Options::ALL |
            OpenSSL::SSL::Options::NO_SSL_V2 |
            OpenSSL::SSL::Options::NO_SSL_V3
          )
          ctx.certificate_chain = "openssl.crt"
          ctx.private_key       = "openssl.key"
        end
      end
    end
  end
end
end
