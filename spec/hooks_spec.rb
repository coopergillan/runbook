require "spec_helper"

RSpec.describe Runbook::Hooks do
  subject { Class.new { extend Runbook::Hooks } }

  describe "register" do
    let(:name) { :my_before_hook }
    let(:type) { :before }
    let(:klass) { Runbook::Entities::Book }
    let(:block) { Proc.new {} }

    it "adds a hook to the list of hooks" do
      subject.register_hook(name, type, klass, &block)

      expect(subject.hooks).to include(
        {name: name, type: type, klass: klass, block: block}
      )
    end

    context "when :before argument is passed" do
      it "adds the new hook before the specified hook" do
        subject.register_hook(:hook1, type, klass, &block)
        subject.register_hook(:hook2, type, klass, before: :hook1, &block)

        hook_names = subject.hooks.map { |hook| hook[:name] }
        expect(hook_names).to eq([:hook2, :hook1])
      end
    end

    context "when bogus :before argument is passed" do
      it "adds the new hook at the end" do
        subject.register_hook(:hook1, type, klass, &block)
        subject.register_hook(:hook2, type, klass, before: :bogus, &block)

        hook_names = subject.hooks.map { |hook| hook[:name] }
        expect(hook_names).to eq([:hook1, :hook2])
      end
    end
  end

  describe "hooks_for" do
    let(:block) { Proc.new {} }
    let (:hook_1) {
      {
        name: :hook_1,
        type: :before,
        klass: Runbook::Entities::Book,
        block: block,
      }
    }
    let (:hook_2) {
      {
        name: :hook_2,
        type: :before,
        klass: Runbook::Entity,
        block: block,
      }
    }
    let (:hook_3) {
      {
        name: :hook_3,
        type: :around,
        klass: Runbook::Statements::Note,
        block: block,
      }
    }
    let (:hook_4) {
      {
        name: :hook_4,
        type: :after,
        klass: Runbook::Statement,
        block: block,
      }
    }
    let(:hooks) { [hook_1, hook_2, hook_3, hook_4] }

    before(:each) do
      hooks.each do |hook|
        subject.register_hook(
          hook[:name], hook[:type], hook[:klass], &hook[:block]
        )
      end
    end

    it "returns a list of hooks of the specified type and class" do
      before_book_hooks = subject.hooks_for(:before, Runbook::Entities::Book)
      expect(before_book_hooks).to include(hook_1, hook_2)
      expect(before_book_hooks).to_not include(hook_3, hook_4)
    end
  end

  describe "invoke_with_hooks" do
    subject {
      Class.new {
        include Runbook::Run

        def self.result
          @result ||= []
        end
      }
    }
    let(:object) {
      Class.new(Runbook::Entity) {
        include Runbook::Hooks::Invoker
        def initialize; end
      }.new
    }
    let(:position) { "0" }
    let(:start_at) { "0" }
    let(:metadata) {
      {position: position, start_at: start_at}
    }
    let (:hook_1) {
      {
        name: :hook_1,
        type: :before,
        klass: object.class,
        block: Proc.new { |object, metadata|
          result << "before hook_1"
        },
      }
    }
    let (:hook_2) {
      {
        name: :hook_2,
        type: :before,
        klass: object.class,
        block: Proc.new { |object, metadata|
          result << "before hook_2"
        },
      }
    }
    let (:hook_3) {
      {
        name: :hook_3,
        type: :around,
        klass: object.class,
        block: Proc.new { |object, metadata, block|
          result << "around before hook_3"
          block.call(object, metadata)
          result << "around after hook_3"
        },
      }
    }
    let (:hook_4) {
      {
        name: :hook_4,
        type: :around,
        klass: object.class,
        block: Proc.new { |object, metadata, block|
          result << "around before hook_4"
          block.call(object, metadata)
          result << "around after hook_4"

        },
      }
    }
    let (:hook_5) {
      {
        name: :hook_5,
        type: :after,
        klass: object.class,
        block: Proc.new { |object, metadata|
          result << "after hook_5"
        },
      }
    }
    let (:hook_6) {
      {
        name: :hook_6,
        type: :after,
        klass: object.class,
        block: Proc.new { |object, metadata|
          result << "after hook_6"
        },
      }
    }
    let(:hooks) {
      [hook_1, hook_2, hook_3, hook_4, hook_5, hook_6]
    }

    before(:each) do
      subject.hooks.clear
      hooks.each do |hook|
        subject.register_hook(
          hook[:name], hook[:type], hook[:klass], &hook[:block]
        )
      end
    end

    it "invokes all hooks for the object" do
      expected_result = [
        "before hook_1",
        "before hook_2",
        "around before hook_3",
        "around before hook_4",
        "book method invoked",
        "around after hook_4",
        "around after hook_3",
        "after hook_5",
        "after hook_6",
      ]

      object.invoke_with_hooks(subject, object, metadata) do
        subject.result << "book method invoked"
      end

      expect(subject.result).to eq(expected_result)
    end

    context "with position < start_at" do
      let(:position) { "1" }
      let(:start_at) { "2" }

      it "skips the hooks" do
        expected_result = ["book method invoked"]

        object.invoke_with_hooks(subject, object, metadata) do
          subject.result << "book method invoked"
        end

        expect(subject.result).to eq(expected_result)
      end
    end

    context "with position < start_at and a sub-entity" do
      let(:position) { "1" }
      let(:start_at) { "1.1" }

      it "skips the before and around hooks" do
        expected_result = [
          "book method invoked",
          "after hook_5",
          "after hook_6",
        ]

        object.invoke_with_hooks(subject, object, metadata) do
          subject.result << "book method invoked"
        end

        expect(subject.result).to eq(expected_result)
      end
    end
  end
end
