# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "yaml"

module Nuttall
  class Config
    include Common::FsInfo
    include Common::HostHash

    FILE_BASENAME = -".nuttall"

    attr_reader :operations
    attr_writer :user_file

    def initialize
      @operations = []
    end

    def add_operation(op_name)
      return false if ! valid_operation?(op_name)
      operations << op_name if ! operations.member?(op_name)
      true
    end

    def valid_operation?(name)
      %w[create start status stop].member?(name)
    end

    def user_home
      raise "No HOME env var is set" if ! ENV["HOME"]
      ENV["HOME"]
    end

    def user_file
      @user_file ||= begin
        parents = %W[
          #{user_home}/.config #{user_home}/.local/share #{user_home}
        ]
        found = parents.detect { |dir| File.writable?(dir) }
        raise "Cannot find suitable parent dir for config file: Tried: #{parents}" if ! found
        File.join(found, FILE_BASENAME)
      end
    end

    def user_file_settings(ignore_err: true)
      @user_file_settings ||= YAML.load(File.read(user_file)).as_struct
    rescue
      raise if ! ignore_err
      @user_file_settings ||= user_file_defaults
    end

    def load_user_file
      @user_file_settings = nil
      user_file_settings(ignore_err: false)
    end

    def save_user_file
      File.write(user_file, user_file_settings.deep_to_h.to_yaml)
    end

    def user_file_defaults
      {
        container: {
          name:    default_name,
          workdir: default_workdir
        },
        disk: {
          size: {
            start:     "1GB",
            max:       "50%",
            increment: "1GB"
          },
          encrypt: {
            enable:    true
          }
        },
        policy: {
          retain: {
            index:   "1mo",
            exports: "6mo"
          },
          discard: {
            index:   false,
            exports: true
          }
        }
      }.as_struct
    end

    def default_name = @default_name ||= "nuttall-#{host_hash}"

    def default_workdir
      @default_workdir ||= begin
        preferred = %w[/opt /var/local /var/opt /usr/local /usr/share]

        infos = begin
          preferred.map.with_index do |path, idx|
            fs_info(path).merge(index: idx)
          end.sort do |a, b|
            (b[:fs_free] <=> a[:fs_free]) * 2 +
            (a[:index]   <=> b[:index])
          end
        end

        infos.first[:path]
      end
    end
  end
end
