# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

RSpec.describe Nuttall::Config do

  describe "#add_operation" do
    it "returns false on invalid op" do
      expect(subject.add_operation("crazy_op_name")).to be false
    end

    let(:valid_ops) { %w[clean create start status stop] } # Match #valid_operation?

    it "accepts valid unique ops" do
      expect(subject.operations).to be_empty
      valid_ops.each.with_index do |op, idx|
        expect(subject.add_operation(op)).to be true
        expect(subject.operations.member?(op)).to be true
        expect(subject.operations.size).to eq(idx + 1)
      end
    end

    it "does not add dupe ops" do
      expect(subject.operations).to be_empty
      2.times do
        expect(subject.add_operation(valid_ops[1])).to be true
      end
      expect(subject.operations.size).to eq(1)
    end
  end

  describe "#user_home" do
    before do
      @saved_env = ENV["HOME"]
    end

    after do
      ENV["HOME"] = @saved_env
    end

    it "raises if $HOME unset" do
      ENV["HOME"] = nil
      expect { subject.user_home }.to raise_error(/No HOME env/)
    end

    it "returns $HOME" do
      ENV["HOME"] = "yo_buddy"
      expect(subject.user_home).to eq("yo_buddy")
    end
  end

  describe "#user_file" do
    before do
      @saved_env = ENV["HOME"]
      subject.instance_eval { @user_file = nil }
    end

    after do
      ENV["HOME"] = @saved_env
    end

    it "raises on none found" do
      expect(subject).to receive(:user_home).exactly(3).times.and_return("/no_such_dir")
      expect { subject.user_file }.to raise_error(/Cannot find .+ parent dir/)
    end

    it "caches and returns on writable dir" do
      ENV["HOME"] = "/fake_arse_dir"
      part1 = "#{ENV["HOME"]}/.config"
      part2 = "#{part1}/.nuttall"
      expect(File).to receive(:writable?).with(part1).once.and_return(true)
      expect(subject.user_file).to eq(part2)
      expect(subject.instance_eval { @user_file }).to eq(part2)
    end
  end

  describe "#user_file_settings" do
    before do
      subject.instance_eval { @user_file_settings = nil }
      expect(subject).to receive(:user_file).once.and_return(nil) # Forces raise
    end

    it "ignores error if set" do
      expect(subject).to receive(:user_file_defaults).once.and_return("fake")

      expect(subject.instance_eval { @user_file_settings }).to be_nil
      expect(subject.user_file_settings(ignore_err: true)).to eq("fake")
      expect(subject.instance_eval { @user_file_settings }).to eq("fake")
    end

    it "raises error if set" do
      expect { subject.user_file_settings(ignore_err: false) }.to raise_error(/conversion of nil/)
    end
  end

  describe "#load_user_file" do
    it "does not ignore errors" do
      expect(subject).to receive(:user_file).once.and_return(nil) # Forces raise
      expect { subject.load_user_file }.to raise_error(/conversion of nil/)
    end
  end
end
