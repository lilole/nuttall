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

  describe "#save_user_file" do
    it "calls File.write" do
      expect(subject).to receive(:user_file).once.and_return("/fake_arse_file")
      expect(subject).to receive(:user_file_settings).once.and_return({ aa: 11 })
      expect(File).to receive(:write).with("/fake_arse_file", "---\n:aa: 11\n").once.and_return(nil)

      expect { subject.save_user_file }.to_not raise_error
    end
  end

  describe "#parse_disk_size" do
    let(:fs_size) { 11223344 }

    shared_examples "working suffixes tests" do
      context "kilo" do
        it("does 1K")          { expect(test["1K"]).to             eq(1_000) }
        it("does 100K")        { expect(test["100 K"]).to          eq(100_000) }
        it("does 1000K")       { expect(test[" 1000 K "]).to       eq(1_000_000) }
        it("does 1.345K")      { expect(test["1.345K"]).to         eq(1_345) }
        it("does 100.345K")    { expect(test["100.345 K"]).to      eq(100_345) }
        it("does 1000.345K")   { expect(test[" 1000.345 K "]).to   eq(1_000_345) }
        it("does 1k")          { expect(test["1k"]).to             eq(1_000) }
        it("does 100k")        { expect(test["100 k"]).to          eq(100_000) }
        it("does 1000k")       { expect(test[" 1000 k "]).to       eq(1_000_000) }
        it("does 1.345k")      { expect(test["1.345k"]).to         eq(1_345) }
        it("does 100.345k")    { expect(test["100.345 k"]).to      eq(100_345) }
        it("does 1000.345k")   { expect(test[" 1000.345 k "]).to   eq(1_000_345) }
        it("does 1KB")         { expect(test["1KB"]).to            eq(1_000) }
        it("does 100KB")       { expect(test["100 KB"]).to         eq(100_000) }
        it("does 1000KB")      { expect(test[" 1000 KB "]).to      eq(1_000_000) }
        it("does 1.345KB")     { expect(test["1.345KB"]).to        eq(1_345) }
        it("does 100.345KB")   { expect(test["100.345 KB"]).to     eq(100_345) }
        it("does 1000.345KB")  { expect(test[" 1000.345 KB "]).to  eq(1_000_345) }
        it("does 1kb")         { expect(test["1kb"]).to            eq(1_000) }
        it("does 100kb")       { expect(test["100 kb"]).to         eq(100_000) }
        it("does 1000kb")      { expect(test[" 1000 kb "]).to      eq(1_000_000) }
        it("does 1.345kb")     { expect(test["1.345kb"]).to        eq(1_345) }
        it("does 100.345kb")   { expect(test["100.345 kb"]).to     eq(100_345) }
        it("does 1000.345kb")  { expect(test[" 1000.345 kb "]).to  eq(1_000_345) }
        it("does 1KiB")        { expect(test["1KiB"]).to           eq(1_024) }
        it("does 100KiB")      { expect(test["100 KiB"]).to        eq(102_400) }
        it("does 1000KiB")     { expect(test[" 1000 KiB "]).to     eq(1_024_000) }
        it("does 1.345KiB")    { expect(test["1.345KiB"]).to       eq(1_377) }
        it("does 100.345KiB")  { expect(test["100.345 KiB"]).to    eq(102_753) }
        it("does 1000.345KiB") { expect(test[" 1000.345 KiB "]).to eq(1_024_353) }
        it("does 1kib")        { expect(test["1kib"]).to           eq(1_024) }
        it("does 100kib")      { expect(test["100 kib"]).to        eq(102_400) }
        it("does 1000kib")     { expect(test[" 1000 kib "]).to     eq(1_024_000) }
        it("does 1.345kib")    { expect(test["1.345KiB"]).to       eq(1_377) }
        it("does 100.345kib")  { expect(test["100.345 KiB"]).to    eq(102_753) }
        it("does 1000.345kib") { expect(test[" 1000.345 KiB "]).to eq(1_024_353) }
      end

      context "mega" do
        it("does 1M")          { expect(test["1M"]).to             eq(1_000_000) }
        it("does 100M")        { expect(test["100 M"]).to          eq(100_000_000) }
        it("does 1000M")       { expect(test[" 1000 M "]).to       eq(1_000_000_000) }
        it("does 1.345M")      { expect(test["1.345M"]).to         eq(1_345_000) }
        it("does 100.345M")    { expect(test["100.345 M"]).to      eq(100_345_000) }
        it("does 1000.345M")   { expect(test[" 1000.345 M "]).to   eq(1_000_345_000) }
        it("does 1m")          { expect(test["1m"]).to             eq(1_000_000) }
        it("does 100m")        { expect(test["100 m"]).to          eq(100_000_000) }
        it("does 1000m")       { expect(test[" 1000 m "]).to       eq(1_000_000_000) }
        it("does 1.345m")      { expect(test["1.345m"]).to         eq(1_345_000) }
        it("does 100.345m")    { expect(test["100.345 m"]).to      eq(100_345_000) }
        it("does 1000.345m")   { expect(test[" 1000.345 m "]).to   eq(1_000_345_000) }
        it("does 1MB")         { expect(test["1MB"]).to            eq(1_000_000) }
        it("does 100MB")       { expect(test["100 MB"]).to         eq(100_000_000) }
        it("does 1000MB")      { expect(test[" 1000 MB "]).to      eq(1_000_000_000) }
        it("does 1.345MB")     { expect(test["1.345MB"]).to        eq(1_345_000) }
        it("does 100.345MB")   { expect(test["100.345 MB"]).to     eq(100_345_000) }
        it("does 1000.345MB")  { expect(test[" 1000.345 MB "]).to  eq(1_000_345_000) }
        it("does 1mb")         { expect(test["1mb"]).to            eq(1_000_000) }
        it("does 100mb")       { expect(test["100 mb"]).to         eq(100_000_000) }
        it("does 1000mb")      { expect(test[" 1000 mb "]).to      eq(1_000_000_000) }
        it("does 1.345mb")     { expect(test["1.345mb"]).to        eq(1_345_000) }
        it("does 100.345mb")   { expect(test["100.345 mb"]).to     eq(100_345_000) }
        it("does 1000.345mb")  { expect(test[" 1000.345 mb "]).to  eq(1_000_345_000) }
        it("does 1MiB")        { expect(test["1MiB"]).to           eq(1_048_576) }
        it("does 100MiB")      { expect(test["100 MiB"]).to        eq(104_857_600) }
        it("does 1000MiB")     { expect(test[" 1000 MiB "]).to     eq(1_048_576_000) }
        it("does 1.345MiB")    { expect(test["1.345MiB"]).to       eq(1_410_335) }
        it("does 100.345MiB")  { expect(test["100.345 MiB"]).to    eq(105_219_359) }
        it("does 1000.345MiB") { expect(test[" 1000.345 MiB "]).to eq(1_048_937_759) }
        it("does 1mib")        { expect(test["1mib"]).to           eq(1_048_576) }
        it("does 100mib")      { expect(test["100 mib"]).to        eq(104_857_600) }
        it("does 1000mib")     { expect(test[" 1000 mib "]).to     eq(1_048_576_000) }
        it("does 1.345mib")    { expect(test["1.345mib"]).to       eq(1_410_335) }
        it("does 100.345mib")  { expect(test["100.345 mib"]).to    eq(105_219_359) }
        it("does 1000.345mib") { expect(test[" 1000.345 mib "]).to eq(1_048_937_759) }
      end

      context "giga" do
        it("does 1G")          { expect(test["1G"]).to             eq(1_000_000_000) }
        it("does 100G")        { expect(test["100 G"]).to          eq(100_000_000_000) }
        it("does 1000G")       { expect(test[" 1000 G "]).to       eq(1_000_000_000_000) }
        it("does 1.345G")      { expect(test["1.345G"]).to         eq(1_345_000_000) }
        it("does 100.345G")    { expect(test["100.345 G"]).to      eq(100_345_000_000) }
        it("does 1000.345G")   { expect(test[" 1000.345 G "]).to   eq(1_000_345_000_000) }
        it("does 1g")          { expect(test["1g"]).to             eq(1_000_000_000) }
        it("does 100g")        { expect(test["100 g"]).to          eq(100_000_000_000) }
        it("does 1000g")       { expect(test[" 1000 g "]).to       eq(1_000_000_000_000) }
        it("does 1.345g")      { expect(test["1.345g"]).to         eq(1_345_000_000) }
        it("does 100.345g")    { expect(test["100.345 g"]).to      eq(100_345_000_000) }
        it("does 1000.345g")   { expect(test[" 1000.345 g "]).to   eq(1_000_345_000_000) }
        it("does 1GB")         { expect(test["1GB"]).to            eq(1_000_000_000) }
        it("does 100GB")       { expect(test["100 GB"]).to         eq(100_000_000_000) }
        it("does 1000GB")      { expect(test[" 1000 GB "]).to      eq(1_000_000_000_000) }
        it("does 1.345GB")     { expect(test["1.345GB"]).to        eq(1_345_000_000) }
        it("does 100.345GB")   { expect(test["100.345 GB"]).to     eq(100_345_000_000) }
        it("does 1000.345GB")  { expect(test[" 1000.345 GB "]).to  eq(1_000_345_000_000) }
        it("does 1gb")         { expect(test["1gb"]).to            eq(1_000_000_000) }
        it("does 100gb")       { expect(test["100 gb"]).to         eq(100_000_000_000) }
        it("does 1000gb")      { expect(test[" 1000 gb "]).to      eq(1_000_000_000_000) }
        it("does 1.345gb")     { expect(test["1.345gb"]).to        eq(1_345_000_000) }
        it("does 100.345gb")   { expect(test["100.345 gb"]).to     eq(100_345_000_000) }
        it("does 1000.345gb")  { expect(test[" 1000.345 gb "]).to  eq(1_000_345_000_000) }
        it("does 1GiB")        { expect(test["1GiB"]).to           eq(1_073_741_824) }
        it("does 100GiB")      { expect(test["100 GiB"]).to        eq(107_374_182_400) }
        it("does 1000GiB")     { expect(test[" 1000 GiB "]).to     eq(1_073_741_824_000) }
        it("does 1.345GiB")    { expect(test["1.345GiB"]).to       eq(1_444_182_753) }
        it("does 100.345GiB")  { expect(test["100.345 GiB"]).to    eq(107_744_623_329) }
        it("does 1000.345GiB") { expect(test[" 1000.345 GiB "]).to eq(1_074_112_264_929) }
        it("does 1gib")        { expect(test["1gib"]).to           eq(1_073_741_824) }
        it("does 100gib")      { expect(test["100 gib"]).to        eq(107_374_182_400) }
        it("does 1000gib")     { expect(test[" 1000 gib "]).to     eq(1_073_741_824_000) }
        it("does 1.345gib")    { expect(test["1.345gib"]).to       eq(1_444_182_753) }
        it("does 100.345gib")  { expect(test["100.345 gib"]).to    eq(107_744_623_329) }
        it("does 1000.345gib") { expect(test[" 1000.345 gib "]).to eq(1_074_112_264_929) }
      end

      context "tera" do
        it("does 1T")          { expect(test["1T"]).to             eq(1_000_000_000_000) }
        it("does 100T")        { expect(test["100 T"]).to          eq(100_000_000_000_000) }
        it("does 1000T")       { expect(test[" 1000 T "]).to       eq(1_000_000_000_000_000) }
        it("does 1.345T")      { expect(test["1.345T"]).to         eq(1_345_000_000_000) }
        it("does 100.345T")    { expect(test["100.345 T"]).to      eq(100_345_000_000_000) }
        it("does 1000.345T")   { expect(test[" 1000.345 T "]).to   eq(1_000_345_000_000_000) }
        it("does 1t")          { expect(test["1t"]).to             eq(1_000_000_000_000) }
        it("does 100t")        { expect(test["100 t"]).to          eq(100_000_000_000_000) }
        it("does 1000t")       { expect(test[" 1000 t "]).to       eq(1_000_000_000_000_000) }
        it("does 1.345t")      { expect(test["1.345t"]).to         eq(1_345_000_000_000) }
        it("does 100.345t")    { expect(test["100.345 t"]).to      eq(100_345_000_000_000) }
        it("does 1000.345t")   { expect(test[" 1000.345 t "]).to   eq(1_000_345_000_000_000) }
        it("does 1TB")         { expect(test["1TB"]).to            eq(1_000_000_000_000) }
        it("does 100TB")       { expect(test["100 TB"]).to         eq(100_000_000_000_000) }
        it("does 1000TB")      { expect(test[" 1000 TB "]).to      eq(1_000_000_000_000_000) }
        it("does 1.345TB")     { expect(test["1.345TB"]).to        eq(1_345_000_000_000) }
        it("does 100.345TB")   { expect(test["100.345 TB"]).to     eq(100_345_000_000_000) }
        it("does 1000.345TB")  { expect(test[" 1000.345 TB "]).to  eq(1_000_345_000_000_000) }
        it("does 1tb")         { expect(test["1tb"]).to            eq(1_000_000_000_000) }
        it("does 100tb")       { expect(test["100 tb"]).to         eq(100_000_000_000_000) }
        it("does 1000tb")      { expect(test[" 1000 tb "]).to      eq(1_000_000_000_000_000) }
        it("does 1.345tb")     { expect(test["1.345tb"]).to        eq(1_345_000_000_000) }
        it("does 100.345tb")   { expect(test["100.345 tb"]).to     eq(100_345_000_000_000) }
        it("does 1000.345tb")  { expect(test[" 1000.345 tb "]).to  eq(1_000_345_000_000_000) }
        it("does 1TiB")        { expect(test["1TiB"]).to           eq(1_099_511_627_776) }
        it("does 100TiB")      { expect(test["100 TiB"]).to        eq(109_951_162_777_600) }
        it("does 1000TiB")     { expect(test[" 1000 TiB "]).to     eq(1_099_511_627_776_000) }
        it("does 1.345TiB")    { expect(test["1.345TiB"]).to       eq(1_478_843_139_359) }
        it("does 100.345TiB")  { expect(test["100.345 TiB"]).to    eq(110_330_494_289_183) }
        it("does 1000.345TiB") { expect(test[" 1000.345 TiB "]).to eq(1_099_890_959_287_583) }
        it("does 1tib")        { expect(test["1tib"]).to           eq(1_099_511_627_776) }
        it("does 100tib")      { expect(test["100 tib"]).to        eq(109_951_162_777_600) }
        it("does 1000tib")     { expect(test[" 1000 tib "]).to     eq(1_099_511_627_776_000) }
        it("does 1.345tib")    { expect(test["1.345tib"]).to       eq(1_478_843_139_359) }
        it("does 100.345tib")  { expect(test["100.345 tib"]).to    eq(110_330_494_289_183) }
        it("does 1000.345tib") { expect(test[" 1000.345 tib "]).to eq(1_099_890_959_287_583) }
      end

      context "peta" do
        it("does 1P")          { expect(test["1P"]).to             eq(1_000_000_000_000_000) }
        it("does 100P")        { expect(test["100 P"]).to          eq(100_000_000_000_000_000) }
        it("does 1000P")       { expect(test[" 1000 P "]).to       eq(1_000_000_000_000_000_000) }
        it("does 1.345P")      { expect(test["1.345P"]).to         eq(1_345_000_000_000_000) }
        it("does 100.345P")    { expect(test["100.345 P"]).to      eq(100_345_000_000_000_000) }
        it("does 1000.345P")   { expect(test[" 1000.345 P "]).to   eq(1_000_345_000_000_000_000) }
        it("does 1p")          { expect(test["1p"]).to             eq(1_000_000_000_000_000) }
        it("does 100p")        { expect(test["100 p"]).to          eq(100_000_000_000_000_000) }
        it("does 1000p")       { expect(test[" 1000 p "]).to       eq(1_000_000_000_000_000_000) }
        it("does 1.345p")      { expect(test["1.345p"]).to         eq(1_345_000_000_000_000) }
        it("does 100.345p")    { expect(test["100.345 p"]).to      eq(100_345_000_000_000_000) }
        it("does 1000.345p")   { expect(test[" 1000.345 p "]).to   eq(1_000_345_000_000_000_000) }
        it("does 1PB")         { expect(test["1PB"]).to            eq(1_000_000_000_000_000) }
        it("does 100PB")       { expect(test["100 PB"]).to         eq(100_000_000_000_000_000) }
        it("does 1000PB")      { expect(test[" 1000 PB "]).to      eq(1_000_000_000_000_000_000) }
        it("does 1.345PB")     { expect(test["1.345PB"]).to        eq(1_345_000_000_000_000) }
        it("does 100.345PB")   { expect(test["100.345 PB"]).to     eq(100_345_000_000_000_000) }
        it("does 1000.345PB")  { expect(test[" 1000.345 PB "]).to  eq(1_000_345_000_000_000_000) }
        it("does 1pb")         { expect(test["1pb"]).to            eq(1_000_000_000_000_000) }
        it("does 100pb")       { expect(test["100 pb"]).to         eq(100_000_000_000_000_000) }
        it("does 1000pb")      { expect(test[" 1000 pb "]).to      eq(1_000_000_000_000_000_000) }
        it("does 1.345pb")     { expect(test["1.345pb"]).to        eq(1_345_000_000_000_000) }
        it("does 100.345pb")   { expect(test["100.345 pb"]).to     eq(100_345_000_000_000_000) }
        it("does 1000.345pb")  { expect(test[" 1000.345 pb "]).to  eq(1_000_345_000_000_000_000) }
        it("does 1PiB")        { expect(test["1PiB"]).to           eq(1_125_899_906_842_624) }
        it("does 100PiB")      { expect(test["100 PiB"]).to        eq(112_589_990_684_262_400) }
        it("does 1000PiB")     { expect(test[" 1000 PiB "]).to     eq(1_125_899_906_842_624_000) }
        it("does 1.345PiB")    { expect(test["1.345PiB"]).to       eq(1_514_335_374_703_329) }
        it("does 100.345PiB")  { expect(test["100.345 PiB"]).to    eq(112_978_426_152_123_104) }
        it("does 1000.345PiB") { expect(test[" 1000.345 PiB "]).to eq(1_126_288_342_310_484_736) }
        it("does 1pib")        { expect(test["1pib"]).to           eq(1_125_899_906_842_624) }
        it("does 100pib")      { expect(test["100 pib"]).to        eq(112_589_990_684_262_400) }
        it("does 1000pib")     { expect(test[" 1000 pib "]).to     eq(1_125_899_906_842_624_000) }
        it("does 1.345pib")    { expect(test["1.345pib"]).to       eq(1_514_335_374_703_329) }
        it("does 100.345pib")  { expect(test["100.345 pib"]).to    eq(112_978_426_152_123_104) }
        it("does 1000.345pib") { expect(test[" 1000.345 pib "]).to eq(1_126_288_342_310_484_736) }
      end
    end

    shared_examples "working no suffix tests" do
      it("does 10")      { expect(test["10"]).to            eq(10) }
      it("does 20")      { expect(test["20 "]).to           eq(20) }
      it("does 40")      { expect(test[" 40"]).to           eq(40) }
      it("does 80")      { expect(test[" 80 "]).to          eq(80) }
      it("does 100")     { expect(test["\n 100 \n"]).to     eq(100) }
      it("does 10.345")  { expect(test["10.345"]).to        eq(10) }
      it("does 20.456")  { expect(test["20.456 "]).to       eq(20) }
      it("does 40.567")  { expect(test[" 40.567"]).to       eq(41) }
      it("does 80.678")  { expect(test[" 80.678 "]).to      eq(81) }
      it("does 100.789") { expect(test["\n 100.789 \n"]).to eq(101) }
    end

    context "with percent enabled" do
      let(:fs_dir) { "/fake_dir" }

      let(:test) do
        ->(value) { subject.parse_disk_size(value, fs_dir) }
      end

      context "with N% and varied spacing" do
        context "for happy path" do
          before do
            expect(subject).to receive(:fs_info).with(fs_dir).and_return({ fs_size: fs_size })
          end

          it("does 10")    { expect(test["10%"]).to           eq(1122334) }
          it("does 20")    { expect(test["20 %"]).to          eq(2244669) }
          it("does 40")    { expect(test[" 40% "]).to         eq(4489338) }
          it("does 80")    { expect(test[" 80 % "]).to        eq(8978675) }
          it("does 100")   { expect(test["\n 100  % \n"]).to  eq(11223344) }
          it("does 10.30") { expect(test["10.30%"]).to        eq(1156004) }
          it("does 10.43") { expect(test["10.43 %"]).to       eq(1170595) }
          it("does 10.56") { expect(test[" 10.56% "]).to      eq(1185185) }
          it("does 10.69") { expect(test[" 10.69 % "]).to     eq(1199775) }
          it("does 10.7")  { expect(test["\n 10.7  % \n"]).to eq(1200898) }
        end # for happy path

        context "for fail path" do
          before do
            expect(subject).to_not receive(:fs_info)
          end

          it("does 1z")      { expect(test["1z%"]).to              be_nil }
          it("does 2z")      { expect(test["2z %"]).to             be_nil }
          it("does 4z")      { expect(test[" 4z% "]).to            be_nil }
          it("does 8z")      { expect(test[" 8z % "]).to           be_nil }
          it("does 10z")     { expect(test["\n 10z  % \n"]).to     be_nil }
          it("does z1")      { expect(test["z1%"]).to              be_nil }
          it("does z2")      { expect(test["z2 %"]).to             be_nil }
          it("does z4")      { expect(test[" z4% "]).to            be_nil }
          it("does z8")      { expect(test[" z8 % "]).to           be_nil }
          it("does z10")     { expect(test["\n z10  % \n"]).to     be_nil }
          it("does 1.345z")  { expect(test["1.345z%"]).to          be_nil }
          it("does 2.345z")  { expect(test["2.345z %"]).to         be_nil }
          it("does 4.345z")  { expect(test[" 4.345z% "]).to        be_nil }
          it("does 8.345z")  { expect(test[" 8.345z % "]).to       be_nil }
          it("does 10.345z") { expect(test["\n 10.345z  % \n"]).to be_nil }
          it("does z1.345")  { expect(test["z1.345%"]).to          be_nil }
          it("does z2.345")  { expect(test["z2.345 %"]).to         be_nil }
          it("does z4.345")  { expect(test[" z4.345% "]).to        be_nil }
          it("does z8.345")  { expect(test[" z8.345 % "]).to       be_nil }
          it("does z10.345") { expect(test["\n z10.345  % \n"]).to be_nil }
        end # for fail path
      end

      context "with multiplier suffix" do
        before do
          expect(subject).to_not receive(:fs_info)
        end

        context "for happy path" do
          it_behaves_like "working suffixes tests"
        end

        context "for fail path" do
          it("does 1zK")        { expect(test["1zK"]).to                be_nil }
          it("does 2zM")        { expect(test["2z M"]).to               be_nil }
          it("does 4zG")        { expect(test[" 4zG "]).to              be_nil }
          it("does 8zT")        { expect(test[" 8z T "]).to             be_nil }
          it("does 10zP")       { expect(test["\n 10z  P \n"]).to       be_nil }
          it("does z1K")        { expect(test["z1K"]).to                be_nil }
          it("does z2M")        { expect(test["z2 M"]).to               be_nil }
          it("does z4G")        { expect(test[" z4G "]).to              be_nil }
          it("does z8T")        { expect(test[" z8 T "]).to             be_nil }
          it("does z10P")       { expect(test["\n z10  P \n"]).to       be_nil }
          it("does 1zKB")       { expect(test["1zKB"]).to               be_nil }
          it("does 2zMB")       { expect(test["2z MB"]).to              be_nil }
          it("does 4zGB")       { expect(test[" 4zGB "]).to             be_nil }
          it("does 8zTB")       { expect(test[" 8z TB "]).to            be_nil }
          it("does 10zPB")      { expect(test["\n 10z  PB \n"]).to      be_nil }
          it("does z1KB")       { expect(test["z1KB"]).to               be_nil }
          it("does z2MB")       { expect(test["z2 MB"]).to              be_nil }
          it("does z4GB")       { expect(test[" z4GB "]).to             be_nil }
          it("does z8TB")       { expect(test[" z8 TB "]).to            be_nil }
          it("does z10PB")      { expect(test["\n z10  PB \n"]).to      be_nil }
          it("does 1zKiB")      { expect(test["1zKiB"]).to              be_nil }
          it("does 2zMiB")      { expect(test["2z MiB"]).to             be_nil }
          it("does 4zGiB")      { expect(test[" 4zGiB "]).to            be_nil }
          it("does 8zTiB")      { expect(test[" 8z TiB "]).to           be_nil }
          it("does 10zPiB")     { expect(test["\n 10z  PiB \n"]).to     be_nil }
          it("does z1KiB")      { expect(test["z1KiB"]).to              be_nil }
          it("does z2MiB")      { expect(test["z2 MiB"]).to             be_nil }
          it("does z4GiB")      { expect(test[" z4GiB "]).to            be_nil }
          it("does z8TiB")      { expect(test[" z8 TiB "]).to           be_nil }
          it("does z10PiB")     { expect(test["\n z10  PiB \n"]).to     be_nil }
          it("does 1zk")        { expect(test["1zk"]).to                be_nil }
          it("does 2zm")        { expect(test["2z m"]).to               be_nil }
          it("does 4zg")        { expect(test[" 4zg "]).to              be_nil }
          it("does 8zt")        { expect(test[" 8z t "]).to             be_nil }
          it("does 10zp")       { expect(test["\n 10z  p \n"]).to       be_nil }
          it("does z1k")        { expect(test["z1k"]).to                be_nil }
          it("does z2m")        { expect(test["z2 m"]).to               be_nil }
          it("does z4g")        { expect(test[" z4g "]).to              be_nil }
          it("does z8t")        { expect(test[" z8 t "]).to             be_nil }
          it("does z10p")       { expect(test["\n z10  p \n"]).to       be_nil }
          it("does 1zkb")       { expect(test["1zkb"]).to               be_nil }
          it("does 2zmb")       { expect(test["2z mb"]).to              be_nil }
          it("does 4zgb")       { expect(test[" 4zgb "]).to             be_nil }
          it("does 8ztb")       { expect(test[" 8z tb "]).to            be_nil }
          it("does 10zpb")      { expect(test["\n 10z  pb \n"]).to      be_nil }
          it("does z1kb")       { expect(test["z1kb"]).to               be_nil }
          it("does z2mb")       { expect(test["z2 mb"]).to              be_nil }
          it("does z4gb")       { expect(test[" z4gb "]).to             be_nil }
          it("does z8tb")       { expect(test[" z8 tb "]).to            be_nil }
          it("does z10pb")      { expect(test["\n z10  pb \n"]).to      be_nil }
          it("does 1zkib")      { expect(test["1zkib"]).to              be_nil }
          it("does 2zmib")      { expect(test["2z mib"]).to             be_nil }
          it("does 4zgib")      { expect(test[" 4zgib "]).to            be_nil }
          it("does 8ztib")      { expect(test[" 8z tib "]).to           be_nil }
          it("does 10zpib")     { expect(test["\n 10z  pib \n"]).to     be_nil }
          it("does z1kib")      { expect(test["z1kib"]).to              be_nil }
          it("does z2mib")      { expect(test["z2 mib"]).to             be_nil }
          it("does z4gib")      { expect(test[" z4gib "]).to            be_nil }
          it("does z8tib")      { expect(test[" z8 tib "]).to           be_nil }
          it("does z10pib")     { expect(test["\n z10  pib \n"]).to     be_nil }
          it("does 1.345zK")    { expect(test["1.345zK"]).to            be_nil }
          it("does 2.345zM")    { expect(test["2.345z M"]).to           be_nil }
          it("does 4.345zG")    { expect(test[" 4.345zG "]).to          be_nil }
          it("does 8.345zT")    { expect(test[" 8.345z T "]).to         be_nil }
          it("does 10.345zP")   { expect(test["\n 10.345z  P \n"]).to   be_nil }
          it("does z1.345K")    { expect(test["z1.345K"]).to            be_nil }
          it("does z2.345M")    { expect(test["z2.345 M"]).to           be_nil }
          it("does z4.345G")    { expect(test[" z4.345G "]).to          be_nil }
          it("does z8.345T")    { expect(test[" z8.345 T "]).to         be_nil }
          it("does z10.345P")   { expect(test["\n z10.345  P \n"]).to   be_nil }
          it("does 1.345zKB")   { expect(test["1.345zKB"]).to           be_nil }
          it("does 2.345zMB")   { expect(test["2.345z MB"]).to          be_nil }
          it("does 4.345zGB")   { expect(test[" 4.345zGB "]).to         be_nil }
          it("does 8.345zTB")   { expect(test[" 8.345z TB "]).to        be_nil }
          it("does 10.345zPB")  { expect(test["\n 10.345z  PB \n"]).to  be_nil }
          it("does z1.345KB")   { expect(test["z1.345KB"]).to           be_nil }
          it("does z2.345MB")   { expect(test["z2.345 MB"]).to          be_nil }
          it("does z4.345GB")   { expect(test[" z4.345GB "]).to         be_nil }
          it("does z8.345TB")   { expect(test[" z8.345 TB "]).to        be_nil }
          it("does z10.345PB")  { expect(test["\n z10.345  PB \n"]).to  be_nil }
          it("does 1.345zKiB")  { expect(test["1.345zKiB"]).to          be_nil }
          it("does 2.345zMiB")  { expect(test["2.345z MiB"]).to         be_nil }
          it("does 4.345zGiB")  { expect(test[" 4.345zGiB "]).to        be_nil }
          it("does 8.345zTiB")  { expect(test[" 8.345z TiB "]).to       be_nil }
          it("does 10.345zPiB") { expect(test["\n 10.345z  PiB \n"]).to be_nil }
          it("does z1.345KiB")  { expect(test["z1.345KiB"]).to          be_nil }
          it("does z2.345MiB")  { expect(test["z2.345 MiB"]).to         be_nil }
          it("does z4.345GiB")  { expect(test[" z4.345GiB "]).to        be_nil }
          it("does z8.345TiB")  { expect(test[" z8.345 TiB "]).to       be_nil }
          it("does z10.345PiB") { expect(test["\n z10.345  PiB \n"]).to be_nil }
          it("does 1.345zk")    { expect(test["1.345zk"]).to            be_nil }
          it("does 2.345zm")    { expect(test["2.345z m"]).to           be_nil }
          it("does 4.345zg")    { expect(test[" 4.345zg "]).to          be_nil }
          it("does 8.345zt")    { expect(test[" 8.345z t "]).to         be_nil }
          it("does 10.345zp")   { expect(test["\n 10.345z  p \n"]).to   be_nil }
          it("does z1.345k")    { expect(test["z1.345k"]).to            be_nil }
          it("does z2.345m")    { expect(test["z2.345 m"]).to           be_nil }
          it("does z4.345g")    { expect(test[" z4.345g "]).to          be_nil }
          it("does z8.345t")    { expect(test[" z8.345 t "]).to         be_nil }
          it("does z10.345p")   { expect(test["\n z10.345  p \n"]).to   be_nil }
          it("does 1.345zkb")   { expect(test["1.345zkb"]).to           be_nil }
          it("does 2.345zmb")   { expect(test["2.345z mb"]).to          be_nil }
          it("does 4.345zgb")   { expect(test[" 4.345zgb "]).to         be_nil }
          it("does 8.345ztb")   { expect(test[" 8.345z tb "]).to        be_nil }
          it("does 10.345zpb")  { expect(test["\n 10.345z  pb \n"]).to  be_nil }
          it("does z1.345kb")   { expect(test["z1.345kb"]).to           be_nil }
          it("does z2.345mb")   { expect(test["z2.345 mb"]).to          be_nil }
          it("does z4.345gb")   { expect(test[" z4.345gb "]).to         be_nil }
          it("does z8.345tb")   { expect(test[" z8.345 tb "]).to        be_nil }
          it("does z10.345pb")  { expect(test["\n z10.345  pb \n"]).to  be_nil }
          it("does 1.345zkib")  { expect(test["1.345zkib"]).to          be_nil }
          it("does 2.345zmib")  { expect(test["2.345z mib"]).to         be_nil }
          it("does 4.345zgib")  { expect(test[" 4.345zgib "]).to        be_nil }
          it("does 8.345ztib")  { expect(test[" 8.345z tib "]).to       be_nil }
          it("does 10.345zpib") { expect(test["\n 10.345z  pib \n"]).to be_nil }
          it("does z1.345kib")  { expect(test["z1.345kib"]).to          be_nil }
          it("does z2.345mib")  { expect(test["z2.345 mib"]).to         be_nil }
          it("does z4.345gib")  { expect(test[" z4.345gib "]).to        be_nil }
          it("does z8.345tib")  { expect(test[" z8.345 tib "]).to       be_nil }
          it("does z10.345pib") { expect(test["\n z10.345  pib \n"]).to be_nil }
        end # for fail path
      end

      context "with no suffix" do
        before do
          expect(subject).to_not receive(:fs_info)
        end

        context "for happy path" do
          it_behaves_like "working no suffix tests"
        end

        context "for fail path" do
          it("does 10z")      { expect(test["10z"]).to            be_nil }
          it("does 20z")      { expect(test["20z "]).to           be_nil }
          it("does 40z")      { expect(test[" 40z"]).to           be_nil }
          it("does 80z")      { expect(test[" 80z "]).to          be_nil }
          it("does 100z")     { expect(test["\n 100z \n"]).to     be_nil }
          it("does 10.345z")  { expect(test["10.345z"]).to        be_nil }
          it("does 20.456z")  { expect(test["20.456z "]).to       be_nil }
          it("does 40.567z")  { expect(test[" 40.567z"]).to       be_nil }
          it("does 80.678z")  { expect(test[" 80.678z "]).to      be_nil }
          it("does 100.789z") { expect(test["\n 100.789z \n"]).to be_nil }
          it("does z10")      { expect(test["z10"]).to            be_nil }
          it("does z20")      { expect(test["z20 "]).to           be_nil }
          it("does z40")      { expect(test[" z40"]).to           be_nil }
          it("does z80")      { expect(test[" z80 "]).to          be_nil }
          it("does z100")     { expect(test["\n z100 \n"]).to     be_nil }
          it("does z10.345")  { expect(test["z10.345"]).to        be_nil }
          it("does z20.456")  { expect(test["z20.456 "]).to       be_nil }
          it("does z40.567")  { expect(test[" z40.567"]).to       be_nil }
          it("does z80.678")  { expect(test[" z80.678 "]).to      be_nil }
          it("does z100.789") { expect(test["\n z100.789 \n"]).to be_nil }
        end # for fail path
      end
    end

    context "with % disabled" do
      let(:test) do
        ->(value) { subject.parse_disk_size(value) }
      end

      before do
        expect(subject).to_not receive(:fs_info)
      end

      context "with N% and varied spacing" do
        it("does 10")      { expect(test["10%"]).to              be_nil }
        it("does 20")      { expect(test["20 %"]).to             be_nil }
        it("does 40")      { expect(test[" 40% "]).to            be_nil }
        it("does 80")      { expect(test[" 80 % "]).to           be_nil }
        it("does 100")     { expect(test["\n 100  % \n"]).to     be_nil }
        it("does 10.30")   { expect(test["10.30%"]).to           be_nil }
        it("does 10.43")   { expect(test["10.43 %"]).to          be_nil }
        it("does 10.56")   { expect(test[" 10.56% "]).to         be_nil }
        it("does 10.69")   { expect(test[" 10.69 % "]).to        be_nil }
        it("does 10.7")    { expect(test["\n 10.7  % \n"]).to    be_nil }
        it("does 1z")      { expect(test["1z%"]).to              be_nil }
        it("does 2z")      { expect(test["2z %"]).to             be_nil }
        it("does 4z")      { expect(test[" 4z% "]).to            be_nil }
        it("does 8z")      { expect(test[" 8z % "]).to           be_nil }
        it("does 10z")     { expect(test["\n 10z  % \n"]).to     be_nil }
        it("does z1")      { expect(test["z1%"]).to              be_nil }
        it("does z2")      { expect(test["z2 %"]).to             be_nil }
        it("does z4")      { expect(test[" z4% "]).to            be_nil }
        it("does z8")      { expect(test[" z8 % "]).to           be_nil }
        it("does z10")     { expect(test["\n z10  % \n"]).to     be_nil }
        it("does 1.345z")  { expect(test["1.345z%"]).to          be_nil }
        it("does 2.345z")  { expect(test["2.345z %"]).to         be_nil }
        it("does 4.345z")  { expect(test[" 4.345z% "]).to        be_nil }
        it("does 8.345z")  { expect(test[" 8.345z % "]).to       be_nil }
        it("does 10.345z") { expect(test["\n 10.345z  % \n"]).to be_nil }
        it("does z1.345")  { expect(test["z1.345%"]).to          be_nil }
        it("does z2.345")  { expect(test["z2.345 %"]).to         be_nil }
        it("does z4.345")  { expect(test[" z4.345% "]).to        be_nil }
        it("does z8.345")  { expect(test[" z8.345 % "]).to       be_nil }
        it("does z10.345") { expect(test["\n z10.345  % \n"]).to be_nil }
      end

      context "with multiplier suffix" do
        it_behaves_like "working suffixes tests"
      end

      context "with no suffix" do
        it_behaves_like "working no suffix tests"
      end
    end
  end # #parse_disk_size
end
