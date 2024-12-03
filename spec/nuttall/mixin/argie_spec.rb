# frozen_string_literal: true
#
# Copyright 2024 Dan Higgins
# SPDX-License-Identifier: Apache-2.0

RSpec.describe Nuttall::Mixin::Argie do
  subject do
    my_class = Class.new do
      include Nuttall::Mixin::Argie
    end
    my_class.new
  end

  describe ".new" do
    let(:test_class) { Nuttall::Mixin::Argie::ArgieWrapper }
    let(:args)       { ["fake"] }
    let(:arg_proc)   { ->(wrapper) { nil } }

    it "saves args" do
      test = test_class.new(args, arg_proc)
      expect(test.args).to eq(args)
    end

    it "saves arg processor" do
      test = test_class.new(args, arg_proc)
      expect(test.arg_proc).to eq(arg_proc)
    end

    it "does not take block" do
      test = -> { test_class.new(args, &arg_proc) }
      expect(&test).to raise_error(/wrong number of arguments/)
    end

    it "resets index" do
      expect_any_instance_of(test_class).to receive(:reset!).once.and_call_original
      test = test_class.new(args, arg_proc)
      expect(test.index).to eq(args.size)
    end

    it "calls #main_loop" do
      expect_any_instance_of(test_class).to receive(:main_loop).once
      test_class.new(args, arg_proc)
    end
  end

  describe "#option?" do
    context "takes empty args" do
      it "with no block" do
        test = ->(arg) { arg.option? }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end

      it "with a block" do
        test = ->(arg) { arg.option? { nil } }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end
    end

    context "takes var args" do
      it "with one list" do
        test = ->(arg) { arg.option?(%w[a b c x]) }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end

      it "with many lists" do
        test = ->(arg) { arg.option?(%w[a b], %w[c x]) }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end

      it "with no lists" do
        test = ->(arg) { arg.option?("a", "b", "c", "x") }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end
    end

    it "takes regex args" do
      test = ->(arg) { arg.option?(/aaa/, /bbb/) }
      expect { subject.argie(%w[-x], &test) }.to_not raise_error
    end

    context "with short options" do
      context "with no param value" do
        it "matches single char" do
          ok = nil
          test = ->(arg) { arg.option?(%w[a b c x]) { ok = true } }
          subject.argie(%w[-x], &test)
          expect(ok).to be(true)
        end

        it "matches in multi chars" do
          ok = nil
          test = ->(arg) { arg.option?(%w[a b c y]) { ok = true } }
          subject.argie(%w[-xyz], &test)
          expect(ok).to be(true)
        end
      end

      context "with param value" do
        context "matches single char" do
          let(:test) { ->(arg) { arg.option?(%w[x=]) { @value = arg.value } } }

          it "with space" do
            @value = nil
            subject.argie(%w[-x fake], &test)
            expect(@value).to eq("fake")
          end

          it "without space" do
            @value = nil
            subject.argie(%w[-xfake], &test)
            expect(@value).to eq("fake")
          end
        end

        it "fails in multi chars" do
          value = "fake"
          test = ->(arg) { arg.option?(%w[y=]) { value = arg.value } }
          subject.argie(%w[-xyz fake], &test)
          expect(value).to_not eq("fake")
        end
      end
    end

    context "with long options" do
      context "with no param value" do
        it "matches exact word" do
          ok = nil
          test = ->(arg) { arg.option?(%w[aaa bbb long-x]) { ok = true } }
          subject.argie(%w[--long-x], &test)
          expect(ok).to be(true)
        end
      end

      context "with param value" do
        it "matches with =" do
          value = nil
          test = ->(arg) { arg.option?(%w[aaa= bbb= long-x=]) { value = arg.value } }
          subject.argie(%w[--long-x=fake], &test)
          expect(value).to eq("fake")
        end

        it "matches without =" do
          value = nil
          test = ->(arg) { arg.option?(%w[aaa= bbb= long-x=]) { value = arg.value } }
          subject.argie(%w[--long-x fake], &test)
          expect(value).to eq("fake")
        end
      end
    end
  end

  describe "#is?" do
    context "takes var args" do
      it "with one list" do
        test = ->(arg) { arg.is?(%w[aaa bbb xxx]) }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end

      it "with many lists" do
        test = ->(arg) { arg.is?(%w[aaa bbb], %w[xxx]) }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end

      it "with no lists" do
        test = ->(arg) { arg.is?("aaa", "bbb", "xxx") }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end

      it "with regexes" do
        test = ->(arg) { arg.is?(/aaa/, /bbb/, /xxx/) }
        expect { subject.argie(%w[-x], &test) }.to_not raise_error
      end
    end

    it "matches regex" do
      ok = nil
      test = ->(arg) { arg.is?(/aaa/, /bbb/, /xxx/) { ok = true } }
      subject.argie(%w[a b xxx], &test)
      expect(ok).to eq(true)
    end

    it "matches non-regex" do
      ok = nil
      test = ->(arg) { arg.is?(%w[aaa bbb xxx]) { ok = true } }
      subject.argie(%w[a b xxx], &test)
      expect(ok).to eq(true)
    end

    it "allows no block" do
      ok = nil
      test = ->(arg) { ok = arg.is?(%w[aaa bbb xxx]) }
      subject.argie(%w[a b xxx], &test)
      expect(ok).to eq(true)
    end

    it "marks used if matched" do
      wrapper = nil
      test = ->(arg) { wrapper ||= arg; arg.is?(%w[aaa bbb xxx]) }
      subject.argie(%w[a b xxx], &test)
      expect(wrapper.used?).to eq(true)
    end
  end

  describe "#consume" do
    it "takes a range" do
      test = ->(arg) { arg.consume(1..2) if arg.is?("b") }
      expect { subject.argie(%w[a b c d e], &test) }.to_not raise_error
    end

    it "raises on non-range" do
      test = ->(arg) { arg.consume(1) if arg.is?("b") }
      expect { subject.argie(%w[a b c d e], &test) }.to raise_error(/undefined method `first'/)
    end

    it "marks used" do
      wrapper = nil
      test = ->(arg) { wrapper ||= arg; arg.consume(1..2) if arg.raw == "b" }
      subject.argie(%w[a b c d e], &test)
      expect(wrapper.used?).to eq(true)
    end

    it "changes index" do
      indexes = []
      test = ->(arg) { indexes << arg.index; arg.consume(1..2) if arg.raw == "b" }
      subject.argie(%w[a b c d e], &test)
      expect(indexes).to eq([0, 1, 4])
    end

    it "returns args for range" do
      values = nil
      test = ->(arg) { values = arg.consume(1..2) if arg.raw == "b" }
      subject.argie(%w[a b c d e], &test)
      expect(values).to eq(%w[c d])
    end
  end

  describe "#reset!" do
    it "takes 0 args" do
      stop = false
      test = ->(arg) { (stop = true; arg.reset!) if ! stop }
      expect { subject.argie(%w[a b], &test) }.to_not raise_error
      expect(stop).to eq(true)
    end

    it "takes an index arg" do
      stop = false
      test = ->(arg) { (stop = true; arg.reset!(1)) if ! stop }
      subject.argie(%w[a b], &test)
      expect(stop).to eq(true)
    end

    it "resets index" do
      stop = false; indexes = []
      test = ->(arg) { indexes << arg.index; (stop = true; arg.reset!) if arg.index == 1 && ! stop }
      subject.argie(%w[a b], &test)
      expect(indexes).to eq([0, 1, 0, 1])
    end

    it "uses given index" do
      stop = false; value = nil
      test = ->(arg) { (stop = true; arg.reset!; value = arg.raw) if ! stop }
      subject.argie(%w[a b], &test)
      expect(stop).to eq(true)
      expect(value).to eq("b")
    end

    it "returns self" do
      stop = false; wrapper1 = wrapper2 = nil
      test = ->(arg) { wrapper1 ||= arg; (stop = true; wrapper2 = arg.reset!) if ! stop }
      subject.argie(%w[a b], &test)
      expect(stop).to eq(true)
      expect(wrapper2).to be(wrapper1)
    end
  end

  describe "#literal?" do
    it "takes a block" do
    end

    it "takes no block" do
    end

    it "is false for option" do
    end

    it "is true for non-option" do
    end

    it "calls block if non-option" do
    end

    it "ignores block if option" do
    end
  end

  describe "#value" do
    it "returns param for long option with =" do
    end

    it "returns param for long option without =" do
    end

    it "returns param for short option with space" do
    end

    it "returns param for short option with no space" do
    end

    it "marks used if matches long param" do
    end

    it "marks used if matches short param" do
    end

    it "returns arg if not option" do
    end

    it "marks used if not option" do
    end
  end

  describe "#next!" do
    it "increments index" do
    end

    it "marks used" do
    end

    it "returns next arg" do
    end
  end

  describe "#parse_options?" do
    it "returns true by default" do
    end

    it "returns false after --" do
    end
  end

  describe "#raw" do
    it "marks used" do
    end

    it "returns arg unchanged" do
    end
  end

  describe "#unused?" do
    it "returns true by default" do
    end

    it "returns false if matched short option" do
    end

    it "returns false if matched long option" do
    end

    it "returns false after #value" do
    end
  end

  describe "#unused!" do
    it "negates used mark" do
    end

    it "returns self" do
    end
  end

  describe "#used?" do
    it "returns false by default" do
    end

    it "returns true if matched short option" do
    end

    it "returns true if matched long option" do
    end

    it "returns true after #value" do
    end
  end

  describe "#used!" do
    it "resets used mark" do
    end

    it "returns self" do
    end
  end
end
