# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "fileutils"
require "yaml"

module Nuttall
  class Config
    include Mixin::FsInfo
    include Mixin::HostHash

    def self.valid_operations = %w[clean config create start status stop]

    def self.valid_operation?(name) = valid_operations.member?(name)

    attr_reader :operations
    attr_writer :user_file

    def initialize
      @operations = []
    end

    def add_operation(op_name)
      return false if ! Config.valid_operation?(op_name)
      operations << op_name if ! operations.member?(op_name)
      true
    end

    def user_home
      raise "No HOME env var is set" if ! ENV["HOME"]
      ENV["HOME"]
    end

    def defaults_file_dir
      @defaults_file_dir ||= begin
        parents = %W[
          #{user_home}/.config/#{file_basename}
          #{user_home}/.local/share/#{file_basename}
          #{user_home}/.#{file_basename}
        ]
        parents.detect { |dir| File.writable?(File.dirname(dir)) } or
          raise "Cannot find suitable parent dir for defaults file: Tried: #{parents}"
      end
    end

    def file_basename = "nuttall"

    def defaults_file = File.join(defaults_file_dir, "defaults.yml")

    def user_file = @user_file ||= defaults_file # Can be changed via attr

    def user_file_settings(ignore_err: true)
      @user_file_settings ||= YAML.load(File.read(user_file)).overlay(user_file_defaults_hash).as_struct
    rescue
      raise if ! ignore_err
      @user_file_settings ||= user_file_defaults
    end

    def load_user_file
      @user_file_settings = nil
      user_file_settings(ignore_err: false)
    end

    def user_file_text = user_file_settings.deep_to_h.to_yaml

    def save_user_file(path=nil)
      path ||= user_file
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir) if ! File.directory?(dir)
      File.write(path, user_file_text)
    end

    DISK_SIZE_REGEX = /\A([\d,_]+(\.[\d,_]+)?)\s*(([kmgtp])(ib|b?)?|%)?\z/.freeze

    def parse_disk_size(value, dir=nil)
      rem = DISK_SIZE_REGEX.match(value.to_s.strip.downcase)
      return nil if ! rem

      num = rem[1].gsub(/[^\d.]+/, "").to_f
      return num.round if ! rem[3]

      if rem[3] == "%"
        return nil if ! dir
        num /= 100.0
        mult = fs_info(dir)[:fs_size]
      else
        base = (rem[5] == "b") ? 1000 : 1024
        pow  = "kmgtp".index(rem[4]) + 1
        mult = base**pow
      end

      (num * mult).round
    end

    DURATION_REGEX = -> do
      periods = "s(ec(onds?)?)?|mi(n(utes?)?)?|h(r|ours?)?|d(ays?)?|w(k|eeks?)?|mo(n(ths?)?)?|y(r|ears?)?"
      /\A([\d,_]+(\.[\d,_]+)?)\s*(#{periods})?\z/
    end.call.freeze

    def parse_duration(value)
      rem = DURATION_REGEX.match(value.to_s.strip.downcase)
      return nil if ! rem

      num = rem[1].gsub(/[^\d.]+/, "").to_f
      per = rem[3]
      return num.round if ! per

      # Month is 30.5 days; year is 365.25 days
      mults = { "s" => 1, "mi" => 60, "h" => 3600, "d" => 86400, "w" => 604800, "mo" => 2635200, "y" => 31557600 }
      mult = mults.detect { |k, v| per.start_with?(k) }[1]

      (num * mult).round
    end

    def user_file_defaults = user_file_defaults_hash.as_struct

    def user_file_defaults_hash
      {
        container: {
          name:    nil,
          workdir: nil
        },
        disk: {
          size: {
            start:     "1 G",
            max:       "50%",
            increment: "1 G"
          },
          encrypt: {
            enable:    true
          }
        },
        policy: {
          retain: {
            index:   "1 mo",
            exports: "6 mo"
          },
          discard: {
            index:   false,
            exports: true
          },
          key: {
            container: true
          }
        }
      }
    end

    def default_name = @default_name ||= "#{file_basename}-#{config_id}"

    def config_id = @config_id ||= host_hash

    PREFERRED_WORKDIRS = %w[/opt /var/local /var/opt /usr/local /usr/share].freeze

    def default_workdir
      @default_workdir ||= begin
        infos = begin
          PREFERRED_WORKDIRS.map.with_index do |path, idx|
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
