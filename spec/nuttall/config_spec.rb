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

  describe "#defaults_file" do
    before do
      @saved_env = ENV["HOME"]
      subject.instance_eval { @user_file = nil }
    end

    after do
      ENV["HOME"] = @saved_env
    end

    it "raises on none found" do
      expect(subject).to receive(:user_home).at_least(1).time.and_return("/no_such_dir")
      expect { subject.user_file }.to raise_error(/Cannot find .+ parent dir/)
    end

    context "caches and returns on writable dir" do
      before do
        ENV["HOME"] = "/fake_arse_dir"
        expect(subject.instance_eval { @user_file }).to be_nil
      end

      after do
        expect(subject.instance_eval { @user_file }).to eq(@part2)
      end

      it "with non dotted dirname" do
        @part1 = "#{ENV["HOME"]}/.config"
        @part2 = "#{@part1}/nuttall/defaults.yml"
        expect(File).to receive(:writable?).at_least(1).time { |arg| arg == @part1 }

        expect(subject.user_file).to eq(@part2)
      end

      it "with dotted dirname" do
        @part1 = "#{ENV["HOME"]}"
        @part2 = "#{@part1}/.nuttall/defaults.yml"
        expect(File).to receive(:writable?).at_least(1).time { |arg| arg == @part1 }

        expect(subject.user_file).to eq(@part2)
      end
    end
  end

  describe "#user_file" do
    let(:fake_result) { "/fake_filename" }

    before do
      subject.instance_eval { @user_file = nil }
      expect(subject).to receive(:defaults_file).once.and_return(fake_result)
    end

    it "calls #defaults_file" do
      expect(subject.user_file).to eq(fake_result)
    end

    it "caches" do
      expect(subject.instance_eval { @user_file }).to be_nil
      subject.user_file
      expect(subject.instance_eval { @user_file }).to eq(fake_result)
    end
  end

  describe "#user_file_settings" do
    before do
      subject.instance_eval { @user_file_settings = nil }
      expect(subject).to receive(:user_file).once.and_return(nil) # Forces raise
    end

    it "ignores error" do
      expect(subject).to receive(:user_file_defaults).once.and_return("fake")

      expect(subject.instance_eval { @user_file_settings }).to be_nil
      expect(subject.user_file_settings).to eq("fake")
      expect(subject.instance_eval { @user_file_settings }).to eq("fake")
    end
  end

  describe "#load_user_file" do
    before do
      expect(subject).to receive(:user_file).once.and_return(nil) # Forces raise
    end

    it "does not ignore errors" do
      expect { subject.load_user_file }.to raise_error(/conversion of nil/)
    end

    it "ignores error if set" do
      expect(subject).to receive(:user_file_defaults).once.and_return("fake")
      result = nil
      expect { result = subject.load_user_file(ignore_err: true) }.to_not raise_error
      expect(result).to eq("fake")
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
        it("does 1K")          { expect(test["1K"]).to             eq(1_024) }
        it("does 100K")        { expect(test["100 K"]).to          eq(102_400) }
        it("does 1000K")       { expect(test[" 1000 K "]).to       eq(1_024_000) }
        it("does 1.345K")      { expect(test["1.345K"]).to         eq(1_377) }
        it("does 100.345K")    { expect(test["100.345 K"]).to      eq(102_753) }
        it("does 1000.345K")   { expect(test[" 1000.345 K "]).to   eq(1_024_353) }
        it("does 1k")          { expect(test["1k"]).to             eq(1_024) }
        it("does 100k")        { expect(test["100 k"]).to          eq(102_400) }
        it("does 1000k")       { expect(test[" 1000 k "]).to       eq(1_024_000) }
        it("does 1.345k")      { expect(test["1.345k"]).to         eq(1_377) }
        it("does 100.345k")    { expect(test["100.345 k"]).to      eq(102_753) }
        it("does 1000.345k")   { expect(test[" 1000.345 k "]).to   eq(1_024_353) }
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
        it("does 1M")          { expect(test["1M"]).to             eq(1_048_576) }
        it("does 100M")        { expect(test["100 M"]).to          eq(104_857_600) }
        it("does 1000M")       { expect(test[" 1000 M "]).to       eq(1_048_576_000) }
        it("does 1.345M")      { expect(test["1.345M"]).to         eq(1_410_335) }
        it("does 100.345M")    { expect(test["100.345 M"]).to      eq(105_219_359) }
        it("does 1000.345M")   { expect(test[" 1000.345 M "]).to   eq(1_048_937_759) }
        it("does 1m")          { expect(test["1m"]).to             eq(1_048_576) }
        it("does 100m")        { expect(test["100 m"]).to          eq(104_857_600) }
        it("does 1000m")       { expect(test[" 1000 m "]).to       eq(1_048_576_000) }
        it("does 1.345m")      { expect(test["1.345m"]).to         eq(1_410_335) }
        it("does 100.345m")    { expect(test["100.345 m"]).to      eq(105_219_359) }
        it("does 1000.345m")   { expect(test[" 1000.345 m "]).to   eq(1_048_937_759) }
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
        it("does 1G")          { expect(test["1G"]).to             eq(1_073_741_824) }
        it("does 100G")        { expect(test["100 G"]).to          eq(107_374_182_400) }
        it("does 1000G")       { expect(test[" 1000 G "]).to       eq(1_073_741_824_000) }
        it("does 1.345G")      { expect(test["1.345G"]).to         eq(1_444_182_753) }
        it("does 100.345G")    { expect(test["100.345 G"]).to      eq(107_744_623_329) }
        it("does 1000.345G")   { expect(test[" 1000.345 G "]).to   eq(1_074_112_264_929) }
        it("does 1g")          { expect(test["1g"]).to             eq(1_073_741_824) }
        it("does 100g")        { expect(test["100 g"]).to          eq(107_374_182_400) }
        it("does 1000g")       { expect(test[" 1000 g "]).to       eq(1_073_741_824_000) }
        it("does 1.345g")      { expect(test["1.345g"]).to         eq(1_444_182_753) }
        it("does 100.345g")    { expect(test["100.345 g"]).to      eq(107_744_623_329) }
        it("does 1000.345g")   { expect(test[" 1000.345 g "]).to   eq(1_074_112_264_929) }
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
        it("does 1T")          { expect(test["1T"]).to             eq(1_099_511_627_776) }
        it("does 100T")        { expect(test["100 T"]).to          eq(109_951_162_777_600) }
        it("does 1000T")       { expect(test[" 1000 T "]).to       eq(1_099_511_627_776_000) }
        it("does 1.345T")      { expect(test["1.345T"]).to         eq(1_478_843_139_359) }
        it("does 100.345T")    { expect(test["100.345 T"]).to      eq(110_330_494_289_183) }
        it("does 1000.345T")   { expect(test[" 1000.345 T "]).to   eq(1_099_890_959_287_583) }
        it("does 1t")          { expect(test["1t"]).to             eq(1_099_511_627_776) }
        it("does 100t")        { expect(test["100 t"]).to          eq(109_951_162_777_600) }
        it("does 1000t")       { expect(test[" 1000 t "]).to       eq(1_099_511_627_776_000) }
        it("does 1.345t")      { expect(test["1.345t"]).to         eq(1_478_843_139_359) }
        it("does 100.345t")    { expect(test["100.345 t"]).to      eq(110_330_494_289_183) }
        it("does 1000.345t")   { expect(test[" 1000.345 t "]).to   eq(1_099_890_959_287_583) }
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
        it("does 1P")          { expect(test["1P"]).to             eq(1_125_899_906_842_624) }
        it("does 100P")        { expect(test["100 P"]).to          eq(112_589_990_684_262_400) }
        it("does 1000P")       { expect(test[" 1000 P "]).to       eq(1_125_899_906_842_624_000) }
        it("does 1.345P")      { expect(test["1.345P"]).to         eq(1_514_335_374_703_329) }
        it("does 100.345P")    { expect(test["100.345 P"]).to      eq(112_978_426_152_123_104) }
        it("does 1000.345P")   { expect(test[" 1000.345 P "]).to   eq(1_126_288_342_310_484_736) }
        it("does 1p")          { expect(test["1p"]).to             eq(1_125_899_906_842_624) }
        it("does 100p")        { expect(test["100 p"]).to          eq(112_589_990_684_262_400) }
        it("does 1000p")       { expect(test[" 1000 p "]).to       eq(1_125_899_906_842_624_000) }
        it("does 1.345p")      { expect(test["1.345p"]).to         eq(1_514_335_374_703_329) }
        it("does 100.345p")    { expect(test["100.345 p"]).to      eq(112_978_426_152_123_104) }
        it("does 1000.345p")   { expect(test[" 1000.345 p "]).to   eq(1_126_288_342_310_484_736) }
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

  describe "#parse_duration" do
    let(:test) do
      ->(value) { subject.parse_duration(value) }
    end

    context "for happy path" do
      context "with numeric" do
        it("does 10")     { expect(test["10"]).to           eq(10) }
        it("does 20")     { expect(test[" 20"]).to          eq(20) }
        it("does 30")     { expect(test["30 "]).to          eq(30) }
        it("does 40")     { expect(test[" 40 "]).to         eq(40) }
        it("does 50")     { expect(test["\n 50 \n"]).to     eq(50) }
        it("does 10.0")   { expect(test["10.0"]).to         eq(10) }
        it("does 20.234") { expect(test[" 20.234"]).to      eq(20) }
        it("does 30.345") { expect(test["30.345 "]).to      eq(30) }
        it("does 40.456") { expect(test[" 40.456 "]).to     eq(40) }
        it("does 50.567") { expect(test["\n 50.567 \n"]).to eq(51) }
      end

      context "with seconds" do
        it("does 1s")           { expect(test["1s"]).to                   eq(1) }
        it("does 2s")           { expect(test[" 2s"]).to                  eq(2) }
        it("does 3s")           { expect(test["3s "]).to                  eq(3) }
        it("does 4s")           { expect(test[" 4 s "]).to                eq(4) }
        it("does 5s")           { expect(test["\n 5  s \n"]).to           eq(5) }
        it("does 1sec")         { expect(test["1sec"]).to                 eq(1) }
        it("does 2sec")         { expect(test[" 2sec"]).to                eq(2) }
        it("does 3sec")         { expect(test["3sec "]).to                eq(3) }
        it("does 4sec")         { expect(test[" 4 sec "]).to              eq(4) }
        it("does 5sec")         { expect(test["\n 5  sec \n"]).to         eq(5) }
        it("does 1second")      { expect(test["1second"]).to              eq(1) }
        it("does 2second")      { expect(test[" 2second"]).to             eq(2) }
        it("does 3second")      { expect(test["3second "]).to             eq(3) }
        it("does 4second")      { expect(test[" 4 second "]).to           eq(4) }
        it("does 5second")      { expect(test["\n 5  second \n"]).to      eq(5) }
        it("does 1seconds")     { expect(test["1seconds"]).to             eq(1) }
        it("does 2seconds")     { expect(test[" 2seconds"]).to            eq(2) }
        it("does 3seconds")     { expect(test["3seconds "]).to            eq(3) }
        it("does 4seconds")     { expect(test[" 4 seconds "]).to          eq(4) }
        it("does 5seconds")     { expect(test["\n 5  seconds \n"]).to     eq(5) }
        it("does 1.0s")         { expect(test["1.0s"]).to                 eq(1) }
        it("does 2.234s")       { expect(test[" 2.234s"]).to              eq(2) }
        it("does 3.345s")       { expect(test["3.345s "]).to              eq(3) }
        it("does 4.456s")       { expect(test[" 4.456 s "]).to            eq(4) }
        it("does 5.567s")       { expect(test["\n 5.567  s \n"]).to       eq(6) }
        it("does 1.0sec")       { expect(test["1.0sec"]).to               eq(1) }
        it("does 2.234sec")     { expect(test[" 2.234sec"]).to            eq(2) }
        it("does 3.345sec")     { expect(test["3.345sec "]).to            eq(3) }
        it("does 4.456sec")     { expect(test[" 4.456 sec "]).to          eq(4) }
        it("does 5.567sec")     { expect(test["\n 5.567  sec \n"]).to     eq(6) }
        it("does 1.0second")    { expect(test["1.0second"]).to            eq(1) }
        it("does 2.234second")  { expect(test[" 2.234second"]).to         eq(2) }
        it("does 3.345second")  { expect(test["3.345second "]).to         eq(3) }
        it("does 4.456second")  { expect(test[" 4.456 second "]).to       eq(4) }
        it("does 5.567second")  { expect(test["\n 5.567  second \n"]).to  eq(6) }
        it("does 1.0seconds")   { expect(test["1.0seconds"]).to           eq(1) }
        it("does 2.234seconds") { expect(test[" 2.234seconds"]).to        eq(2) }
        it("does 3.345seconds") { expect(test["3.345seconds "]).to        eq(3) }
        it("does 4.456seconds") { expect(test[" 4.456 seconds "]).to      eq(4) }
        it("does 5.567seconds") { expect(test["\n 5.567  seconds \n"]).to eq(6) }
      end

      context "with minutes" do
        it("does 1mi")          { expect(test["1mi"]).to                  eq(60) }
        it("does 2mi")          { expect(test[" 2mi"]).to                 eq(120) }
        it("does 3mi")          { expect(test["3mi "]).to                 eq(180) }
        it("does 4mi")          { expect(test[" 4 mi "]).to               eq(240) }
        it("does 5mi")          { expect(test["\n 5  mi \n"]).to          eq(300) }
        it("does 1min")         { expect(test["1min"]).to                 eq(60) }
        it("does 2min")         { expect(test[" 2min"]).to                eq(120) }
        it("does 3min")         { expect(test["3min "]).to                eq(180) }
        it("does 4min")         { expect(test[" 4 min "]).to              eq(240) }
        it("does 5min")         { expect(test["\n 5  min \n"]).to         eq(300) }
        it("does 1minute")      { expect(test["1minute"]).to              eq(60) }
        it("does 2minute")      { expect(test[" 2minute"]).to             eq(120) }
        it("does 3minute")      { expect(test["3minute "]).to             eq(180) }
        it("does 4minute")      { expect(test[" 4 minute "]).to           eq(240) }
        it("does 5minute")      { expect(test["\n 5  minute \n"]).to      eq(300) }
        it("does 1minutes")     { expect(test["1minutes"]).to             eq(60) }
        it("does 2minutes")     { expect(test[" 2minutes"]).to            eq(120) }
        it("does 3minutes")     { expect(test["3minutes "]).to            eq(180) }
        it("does 4minutes")     { expect(test[" 4 minutes "]).to          eq(240) }
        it("does 5minutes")     { expect(test["\n 5  minutes \n"]).to     eq(300) }
        it("does 1.0mi")        { expect(test["1.0mi"]).to                eq(60) }
        it("does 2.234mi")      { expect(test[" 2.234mi"]).to             eq(134) }
        it("does 3.345mi")      { expect(test["3.345mi "]).to             eq(201) }
        it("does 4.456mi")      { expect(test[" 4.456 mi "]).to           eq(267) }
        it("does 5.567mi")      { expect(test["\n 5.567  mi \n"]).to      eq(334) }
        it("does 1.0min")       { expect(test["1.0min"]).to               eq(60) }
        it("does 2.234min")     { expect(test[" 2.234min"]).to            eq(134) }
        it("does 3.345min")     { expect(test["3.345min "]).to            eq(201) }
        it("does 4.456min")     { expect(test[" 4.456 min "]).to          eq(267) }
        it("does 5.567min")     { expect(test["\n 5.567  min \n"]).to     eq(334) }
        it("does 1.0minute")    { expect(test["1.0minute"]).to            eq(60) }
        it("does 2.234minute")  { expect(test[" 2.234minute"]).to         eq(134) }
        it("does 3.345minute")  { expect(test["3.345minute "]).to         eq(201) }
        it("does 4.456minute")  { expect(test[" 4.456 minute "]).to       eq(267) }
        it("does 5.567minute")  { expect(test["\n 5.567  minute \n"]).to  eq(334) }
        it("does 1.0minutes")   { expect(test["1.0minutes"]).to           eq(60) }
        it("does 2.234minutes") { expect(test[" 2.234minutes"]).to        eq(134) }
        it("does 3.345minutes") { expect(test["3.345minutes "]).to        eq(201) }
        it("does 4.456minutes") { expect(test[" 4.456 minutes "]).to      eq(267) }
        it("does 5.567minutes") { expect(test["\n 5.567  minutes \n"]).to eq(334) }
      end

      context "with hours" do
        it("does 1h")         { expect(test["1h"]).to                 eq(3600) }
        it("does 2h")         { expect(test[" 2h"]).to                eq(7200) }
        it("does 3h")         { expect(test["3h "]).to                eq(10800) }
        it("does 4h")         { expect(test[" 4 h "]).to              eq(14400) }
        it("does 5h")         { expect(test["\n 5  h \n"]).to         eq(18000) }
        it("does 1hr")        { expect(test["1hr"]).to                eq(3600) }
        it("does 2hr")        { expect(test[" 2hr"]).to               eq(7200) }
        it("does 3hr")        { expect(test["3hr "]).to               eq(10800) }
        it("does 4hr")        { expect(test[" 4 hr "]).to             eq(14400) }
        it("does 5hr")        { expect(test["\n 5  hr \n"]).to        eq(18000) }
        it("does 1hour")      { expect(test["1hour"]).to              eq(3600) }
        it("does 2hour")      { expect(test[" 2hour"]).to             eq(7200) }
        it("does 3hour")      { expect(test["3hour "]).to             eq(10800) }
        it("does 4hour")      { expect(test[" 4 hour "]).to           eq(14400) }
        it("does 5hour")      { expect(test["\n 5  hour \n"]).to      eq(18000) }
        it("does 1hours")     { expect(test["1hours"]).to             eq(3600) }
        it("does 2hours")     { expect(test[" 2hours"]).to            eq(7200) }
        it("does 3hours")     { expect(test["3hours "]).to            eq(10800) }
        it("does 4hours")     { expect(test[" 4 hours "]).to          eq(14400) }
        it("does 5hours")     { expect(test["\n 5  hours \n"]).to     eq(18000) }
        it("does 1.0h")       { expect(test["1.0h"]).to               eq(3600) }
        it("does 2.234h")     { expect(test[" 2.234h"]).to            eq(8042) }
        it("does 3.345h")     { expect(test["3.345h "]).to            eq(12042) }
        it("does 4.456h")     { expect(test[" 4.456 h "]).to          eq(16042) }
        it("does 5.567h")     { expect(test["\n 5.567  h \n"]).to     eq(20041) }
        it("does 1.0hr")      { expect(test["1.0hr"]).to              eq(3600) }
        it("does 2.234hr")    { expect(test[" 2.234hr"]).to           eq(8042) }
        it("does 3.345hr")    { expect(test["3.345hr "]).to           eq(12042) }
        it("does 4.456hr")    { expect(test[" 4.456 hr "]).to         eq(16042) }
        it("does 5.567hr")    { expect(test["\n 5.567  hr \n"]).to    eq(20041) }
        it("does 1.0hour")    { expect(test["1.0hour"]).to            eq(3600) }
        it("does 2.234hour")  { expect(test[" 2.234hour"]).to         eq(8042) }
        it("does 3.345hour")  { expect(test["3.345hour "]).to         eq(12042) }
        it("does 4.456hour")  { expect(test[" 4.456 hour "]).to       eq(16042) }
        it("does 5.567hour")  { expect(test["\n 5.567  hour \n"]).to  eq(20041) }
        it("does 1.0hours")   { expect(test["1.0hours"]).to           eq(3600) }
        it("does 2.234hours") { expect(test[" 2.234hours"]).to        eq(8042) }
        it("does 3.345hours") { expect(test["3.345hours "]).to        eq(12042) }
        it("does 4.456hours") { expect(test[" 4.456 hours "]).to      eq(16042) }
        it("does 5.567hours") { expect(test["\n 5.567  hours \n"]).to eq(20041) }
      end

      context "with days" do
        it("does 1d")        { expect(test["1d"]).to                eq(86400) }
        it("does 2d")        { expect(test[" 2d"]).to               eq(172800) }
        it("does 3d")        { expect(test["3d "]).to               eq(259200) }
        it("does 4d")        { expect(test[" 4 d "]).to             eq(345600) }
        it("does 5d")        { expect(test["\n 5  d \n"]).to        eq(432000) }
        it("does 1day")      { expect(test["1day"]).to              eq(86400) }
        it("does 2day")      { expect(test[" 2day"]).to             eq(172800) }
        it("does 3day")      { expect(test["3day "]).to             eq(259200) }
        it("does 4day")      { expect(test[" 4 day "]).to           eq(345600) }
        it("does 5day")      { expect(test["\n 5  day \n"]).to      eq(432000) }
        it("does 1days")     { expect(test["1days"]).to             eq(86400) }
        it("does 2days")     { expect(test[" 2days"]).to            eq(172800) }
        it("does 3days")     { expect(test["3days "]).to            eq(259200) }
        it("does 4days")     { expect(test[" 4 days "]).to          eq(345600) }
        it("does 5days")     { expect(test["\n 5  days \n"]).to     eq(432000) }
        it("does 1.0d")      { expect(test["1.0d"]).to              eq(86400) }
        it("does 2.234d")    { expect(test[" 2.234d"]).to           eq(193018) }
        it("does 3.345d")    { expect(test["3.345d "]).to           eq(289008) }
        it("does 4.456d")    { expect(test[" 4.456 d "]).to         eq(384998) }
        it("does 5.567d")    { expect(test["\n 5.567  d \n"]).to    eq(480989) }
        it("does 1.0day")    { expect(test["1.0day"]).to            eq(86400) }
        it("does 2.234day")  { expect(test[" 2.234day"]).to         eq(193018) }
        it("does 3.345day")  { expect(test["3.345day "]).to         eq(289008) }
        it("does 4.456day")  { expect(test[" 4.456 day "]).to       eq(384998) }
        it("does 5.567day")  { expect(test["\n 5.567  day \n"]).to  eq(480989) }
        it("does 1.0days")   { expect(test["1.0days"]).to           eq(86400) }
        it("does 2.234days") { expect(test[" 2.234days"]).to        eq(193018) }
        it("does 3.345days") { expect(test["3.345days "]).to        eq(289008) }
        it("does 4.456days") { expect(test[" 4.456 days "]).to      eq(384998) }
        it("does 5.567days") { expect(test["\n 5.567  days \n"]).to eq(480989) }
      end

      context "with weeks" do
        it("does 1w")         { expect(test["1w"]).to                 eq(604800) }
        it("does 2w")         { expect(test[" 2w"]).to                eq(1209600) }
        it("does 3w")         { expect(test["3w "]).to                eq(1814400) }
        it("does 4w")         { expect(test[" 4 w "]).to              eq(2419200) }
        it("does 5w")         { expect(test["\n 5  w \n"]).to         eq(3024000) }
        it("does 1wk")        { expect(test["1wk"]).to                eq(604800) }
        it("does 2wk")        { expect(test[" 2wk"]).to               eq(1209600) }
        it("does 3wk")        { expect(test["3wk "]).to               eq(1814400) }
        it("does 4wk")        { expect(test[" 4 wk "]).to             eq(2419200) }
        it("does 5wk")        { expect(test["\n 5  wk \n"]).to        eq(3024000) }
        it("does 1week")      { expect(test["1week"]).to              eq(604800) }
        it("does 2week")      { expect(test[" 2week"]).to             eq(1209600) }
        it("does 3week")      { expect(test["3week "]).to             eq(1814400) }
        it("does 4week")      { expect(test[" 4 week "]).to           eq(2419200) }
        it("does 5week")      { expect(test["\n 5  week \n"]).to      eq(3024000) }
        it("does 1weeks")     { expect(test["1weeks"]).to             eq(604800) }
        it("does 2weeks")     { expect(test[" 2weeks"]).to            eq(1209600) }
        it("does 3weeks")     { expect(test["3weeks "]).to            eq(1814400) }
        it("does 4weeks")     { expect(test[" 4 weeks "]).to          eq(2419200) }
        it("does 5weeks")     { expect(test["\n 5  weeks \n"]).to     eq(3024000) }
        it("does 1.0w")       { expect(test["1.0w"]).to               eq(604800) }
        it("does 2.234w")     { expect(test[" 2.234w"]).to            eq(1351123) }
        it("does 3.345w")     { expect(test["3.345w "]).to            eq(2023056) }
        it("does 4.456w")     { expect(test[" 4.456 w "]).to          eq(2694989) }
        it("does 5.567w")     { expect(test["\n 5.567  w \n"]).to     eq(3366922) }
        it("does 1.0wk")      { expect(test["1.0wk"]).to              eq(604800) }
        it("does 2.234wk")    { expect(test[" 2.234wk"]).to           eq(1351123) }
        it("does 3.345wk")    { expect(test["3.345wk "]).to           eq(2023056) }
        it("does 4.456wk")    { expect(test[" 4.456 wk "]).to         eq(2694989) }
        it("does 5.567wk")    { expect(test["\n 5.567  wk \n"]).to    eq(3366922) }
        it("does 1.0week")    { expect(test["1.0week"]).to            eq(604800) }
        it("does 2.234week")  { expect(test[" 2.234week"]).to         eq(1351123) }
        it("does 3.345week")  { expect(test["3.345week "]).to         eq(2023056) }
        it("does 4.456week")  { expect(test[" 4.456 week "]).to       eq(2694989) }
        it("does 5.567week")  { expect(test["\n 5.567  week \n"]).to  eq(3366922) }
        it("does 1.0weeks")   { expect(test["1.0weeks"]).to           eq(604800) }
        it("does 2.234weeks") { expect(test[" 2.234weeks"]).to        eq(1351123) }
        it("does 3.345weeks") { expect(test["3.345weeks "]).to        eq(2023056) }
        it("does 4.456weeks") { expect(test[" 4.456 weeks "]).to      eq(2694989) }
        it("does 5.567weeks") { expect(test["\n 5.567  weeks \n"]).to eq(3366922) }
      end

      context "with months" do
        it("does 1mo")         { expect(test["1mo"]).to                 eq(2635200) }
        it("does 2mo")         { expect(test[" 2mo"]).to                eq(5270400) }
        it("does 3mo")         { expect(test["3mo "]).to                eq(7905600) }
        it("does 4mo")         { expect(test[" 4 mo "]).to              eq(10540800) }
        it("does 5mo")         { expect(test["\n 5  mo \n"]).to         eq(13176000) }
        it("does 1mon")        { expect(test["1mon"]).to                eq(2635200) }
        it("does 2mon")        { expect(test[" 2mon"]).to               eq(5270400) }
        it("does 3mon")        { expect(test["3mon "]).to               eq(7905600) }
        it("does 4mon")        { expect(test[" 4 mon "]).to             eq(10540800) }
        it("does 5mon")        { expect(test["\n 5  mon \n"]).to        eq(13176000) }
        it("does 1month")      { expect(test["1month"]).to              eq(2635200) }
        it("does 2month")      { expect(test[" 2month"]).to             eq(5270400) }
        it("does 3month")      { expect(test["3month "]).to             eq(7905600) }
        it("does 4month")      { expect(test[" 4 month "]).to           eq(10540800) }
        it("does 5month")      { expect(test["\n 5  month \n"]).to      eq(13176000) }
        it("does 1months")     { expect(test["1months"]).to             eq(2635200) }
        it("does 2months")     { expect(test[" 2months"]).to            eq(5270400) }
        it("does 3months")     { expect(test["3months "]).to            eq(7905600) }
        it("does 4months")     { expect(test[" 4 months "]).to          eq(10540800) }
        it("does 5months")     { expect(test["\n 5  months \n"]).to     eq(13176000) }
        it("does 1.0mo")       { expect(test["1.0mo"]).to               eq(2635200) }
        it("does 2.234mo")     { expect(test[" 2.234mo"]).to            eq(5887037) }
        it("does 3.345mo")     { expect(test["3.345mo "]).to            eq(8814744) }
        it("does 4.456mo")     { expect(test[" 4.456 mo "]).to          eq(11742451) }
        it("does 5.567mo")     { expect(test["\n 5.567  mo \n"]).to     eq(14670158) }
        it("does 1.0mon")      { expect(test["1.0mon"]).to              eq(2635200) }
        it("does 2.234mon")    { expect(test[" 2.234mon"]).to           eq(5887037) }
        it("does 3.345mon")    { expect(test["3.345mon "]).to           eq(8814744) }
        it("does 4.456mon")    { expect(test[" 4.456 mon "]).to         eq(11742451) }
        it("does 5.567mon")    { expect(test["\n 5.567  mon \n"]).to    eq(14670158) }
        it("does 1.0month")    { expect(test["1.0month"]).to            eq(2635200) }
        it("does 2.234month")  { expect(test[" 2.234month"]).to         eq(5887037) }
        it("does 3.345month")  { expect(test["3.345month "]).to         eq(8814744) }
        it("does 4.456month")  { expect(test[" 4.456 month "]).to       eq(11742451) }
        it("does 5.567month")  { expect(test["\n 5.567  month \n"]).to  eq(14670158) }
        it("does 1.0months")   { expect(test["1.0months"]).to           eq(2635200) }
        it("does 2.234months") { expect(test[" 2.234months"]).to        eq(5887037) }
        it("does 3.345months") { expect(test["3.345months "]).to        eq(8814744) }
        it("does 4.456months") { expect(test[" 4.456 months "]).to      eq(11742451) }
        it("does 5.567months") { expect(test["\n 5.567  months \n"]).to eq(14670158) }
      end

      context "with years" do
        it("does 1y")         { expect(test["1y"]).to                 eq(31557600) }
        it("does 2y")         { expect(test[" 2y"]).to                eq(63115200) }
        it("does 3y")         { expect(test["3y "]).to                eq(94672800) }
        it("does 4y")         { expect(test[" 4 y "]).to              eq(126230400) }
        it("does 5y")         { expect(test["\n 5  y \n"]).to         eq(157788000) }
        it("does 1yr")        { expect(test["1yr"]).to                eq(31557600) }
        it("does 2yr")        { expect(test[" 2yr"]).to               eq(63115200) }
        it("does 3yr")        { expect(test["3yr "]).to               eq(94672800) }
        it("does 4yr")        { expect(test[" 4 yr "]).to             eq(126230400) }
        it("does 5yr")        { expect(test["\n 5  yr \n"]).to        eq(157788000) }
        it("does 1year")      { expect(test["1year"]).to              eq(31557600) }
        it("does 2year")      { expect(test[" 2year"]).to             eq(63115200) }
        it("does 3year")      { expect(test["3year "]).to             eq(94672800) }
        it("does 4year")      { expect(test[" 4 year "]).to           eq(126230400) }
        it("does 5year")      { expect(test["\n 5  year \n"]).to      eq(157788000) }
        it("does 1years")     { expect(test["1years"]).to             eq(31557600) }
        it("does 2years")     { expect(test[" 2years"]).to            eq(63115200) }
        it("does 3years")     { expect(test["3years "]).to            eq(94672800) }
        it("does 4years")     { expect(test[" 4 years "]).to          eq(126230400) }
        it("does 5years")     { expect(test["\n 5  years \n"]).to     eq(157788000) }
        it("does 1.0y")       { expect(test["1.0y"]).to               eq(31557600) }
        it("does 2.234y")     { expect(test[" 2.234y"]).to            eq(70499678) }
        it("does 3.345y")     { expect(test["3.345y "]).to            eq(105560172) }
        it("does 4.456y")     { expect(test[" 4.456 y "]).to          eq(140620666) }
        it("does 5.567y")     { expect(test["\n 5.567  y \n"]).to     eq(175681159) }
        it("does 1.0yr")      { expect(test["1.0yr"]).to              eq(31557600) }
        it("does 2.234yr")    { expect(test[" 2.234yr"]).to           eq(70499678) }
        it("does 3.345yr")    { expect(test["3.345yr "]).to           eq(105560172) }
        it("does 4.456yr")    { expect(test[" 4.456 yr "]).to         eq(140620666) }
        it("does 5.567yr")    { expect(test["\n 5.567  yr \n"]).to    eq(175681159) }
        it("does 1.0year")    { expect(test["1.0year"]).to            eq(31557600) }
        it("does 2.234year")  { expect(test[" 2.234year"]).to         eq(70499678) }
        it("does 3.345year")  { expect(test["3.345year "]).to         eq(105560172) }
        it("does 4.456year")  { expect(test[" 4.456 year "]).to       eq(140620666) }
        it("does 5.567year")  { expect(test["\n 5.567  year \n"]).to  eq(175681159) }
        it("does 1.0years")   { expect(test["1.0years"]).to           eq(31557600) }
        it("does 2.234years") { expect(test[" 2.234years"]).to        eq(70499678) }
        it("does 3.345years") { expect(test["3.345years "]).to        eq(105560172) }
        it("does 4.456years") { expect(test[" 4.456 years "]).to      eq(140620666) }
        it("does 5.567years") { expect(test["\n 5.567  years \n"]).to eq(175681159) }
      end
    end # for happy path

    context "for fail path" do
      it("does 1z")    { expect(test["1z"]).to    be_nil }
      it("does 1 z")   { expect(test["1 z"]).to   be_nil }
      it("does 1z s")  { expect(test["1z s"]).to  be_nil }
      it("does 1z mi") { expect(test["1z mi"]).to be_nil }
      it("does 1z h")  { expect(test["1z h"]).to  be_nil }
      it("does 1z d")  { expect(test["1z d"]).to  be_nil }
      it("does 1z w")  { expect(test["1z w"]).to  be_nil }
      it("does 1z mo") { expect(test["1z mo"]).to be_nil }
      it("does 1z y")  { expect(test["1z y"]).to  be_nil }
      it("does z1")    { expect(test["z1"]).to    be_nil }
      it("does z 1")   { expect(test["z 1"]).to   be_nil }
      it("does z1 s")  { expect(test["z1 s"]).to  be_nil }
      it("does z1 mi") { expect(test["z1 mi"]).to be_nil }
      it("does z1 h")  { expect(test["z1 h"]).to  be_nil }
      it("does z1 d")  { expect(test["z1 d"]).to  be_nil }
      it("does z1 w")  { expect(test["z1 w"]).to  be_nil }
      it("does z1 mo") { expect(test["z1 mo"]).to be_nil }
      it("does z1 y")  { expect(test["z1 y"]).to  be_nil }
    end # for fail path
  end # #parse_duration

  describe "#user_file_defaults" do
    it "is a Struct" do
      expect(subject).to_not receive(:default_name)
      expect(subject).to_not receive(:default_workdir)

      expect(Struct === subject.user_file_defaults).to be(true)
    end
  end

  describe "#default_name" do
    before do
      subject.instance_eval { @default_name = nil }
    end

    it "calls host_hash" do
      expect(subject).to receive(:host_hash).once.and_return("fake_hash")

      expect(subject.default_name).to match(/fake_hash/)
    end

    it "caches its value" do
      expect(subject).to receive(:host_hash).once.and_return("fake_hash")

      expect(subject.instance_eval { @default_name }).to be(nil)
      expect(subject.default_name).to match(/fake_hash/)
      expect(subject.instance_eval { @default_name }).to match(/fake_hash/)
      expect(subject.default_name).to match(/fake_hash/)
    end
  end

  describe "#default_workdir" do
    def standard_call(&calc_free)
      tried = []

      expect(subject).to receive(:fs_info).exactly(try_dirs.size).times do |dir|
        tried << dir
        { path: dir, fs_free: calc_free[tried] }
      end

      { dir: subject.default_workdir, tried: tried }
    end

    let(:try_dirs) { Nuttall::Config::PREFERRED_WORKDIRS }

    before do
      subject.instance_eval { @default_workdir = nil }
    end

    it "uses standard dirs" do
      result = standard_call { |_| 100 }
      expect(result[:tried].size).to eq(try_dirs.size)
      expect(try_dirs - result[:tried]).to be_empty
    end

    it "sorts by free space" do
      result = standard_call { |tried_dirs| tried_dirs.size * 100 }
      expect(result[:dir]).to eq(try_dirs.last)
    end

    it "sorts by free space then path" do
      free_index = {}
      result = standard_call do |tried_dirs|
        index = tried_dirs.size - 1
        free = [1, 2].member?(index) ? 200 : 100
        free_index[tried_dirs.last] = free
      end
      expect(free_index.values.uniq.sort).to eq([100, 200])
      expect(free_index.values[1, 2]).to eq([200, 200])
      expect(result[:dir]).to eq(free_index.keys[1])
    end

    it "caches" do
      expect(subject.instance_eval { @default_workdir  }).to be(nil)

      result = standard_call { |_| 100 }
      expect(subject.instance_eval { @default_workdir  }).to eq(result[:dir])

      expect(subject.default_workdir).to eq(result[:dir])
    end
  end
end
