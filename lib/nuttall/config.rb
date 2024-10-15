# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "yaml"

module Nuttall
  class Config
    class << self
      attr_accessor :operation
      attr_writer   :user_file
    end

    def self.user_home
      raise "No HOME env var is set" if ! ENV["HOME"]
      ENV["HOME"]
    end

    def self.user_file
      @user_file ||= begin
        parents = %W[
          #{user_home}/.config #{user_home}/.local/share #{user_home}/
        ]
        found = parents.detect { |dir| File.writable?(dir) }
        raise "Cannot find suitable parent dir for config file: Tried: #{parents}" if ! found
        File.join(found, ".nuttall")
      end
    end

    def self.user_file_settings
      return nil if ! user_file
      @user_file_settings ||= YAML.load(user_file).as_struct
    end

    def self.load_user_file
      @user_file_settings = nil
      user_file_settings
    end
  end
end
