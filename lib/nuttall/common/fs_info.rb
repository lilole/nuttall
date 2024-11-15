# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

require "yaml"

module Nuttall
module Common
  module FsInfo
    include Bash

    ### Return a hash with information about the filesystem the given path is on.
      # The hash will have keys such as:
      #     :path => The absolute path given.
      #     :device => The path's device in major:minor format.
      #     :fs_free => Free bytes on the path's filesystem.
      #
    def fs_info(path)
      path = File.expand_path(path)
      stat = File.exist?(path) ? File.stat(path) : nil

      {}.tap do |result|
        result[:path] = path
        if stat
          result[:device] = "#{stat.dev_major}:#{stat.dev_minor}"
          blkdev = block_devices.detect { |dev| dev["maj:min"] == result[:device] } || {}

          result[:fs_size] = blkdev["fssize"].to_i
          result[:fs_used] = blkdev["fsused"].to_i
          result[:fs_free] = result[:fs_size] - result[:fs_used]
        else
          result[:device] = ""
          %i[fs_size fs_used fs_free].each { result[_1] = 0 }
        end
      end
    end

    ### Return a list of hashes with verbose details about all block devices on
      # the system. This includes all disks and partitions.
      # A sample of one of the hashes:
      #     {"alignment"=>0,
      #      "id-link"=>"nvme-eui.36483230546045100025385800000001-part2",
      #      "id"=>"eui.36483230546045100025385800000001-part2",
      #      "disc-aln"=>0,
      #      "dax"=>false,
      #      "disc-gran"=>512,
      #      "disk-seq"=>1,
      #      "disc-max"=>2199023255040,
      #      "disc-zero"=>false,
      #      "fsavail"=>867127943168,
      #      "fsroots"=>["/"],
      #      "fssize"=>1006823387136,
      #      "fstype"=>"ext4",
      #      "..."=>"..."
      #     }
      # For more details about the results here see:
      #     https://man.archlinux.org/man/lsblk.8
      #
    def block_devices
      @block_devices ||= begin
        ran = bash("lsblk --json --bytes --output-all")
        raise "Failed to query block device data: #{ran.out.inspect}" if ran.fail?

        flatten = ->(hashes) do
          hashes.map do |hash|
            children = hash.delete("children")
            [hash] + (children ? flatten[children] : [])
          end.flatten
        end

        flatten[YAML.load(ran.stdout)["blockdevices"]]
      end
    end
  end
end
end
