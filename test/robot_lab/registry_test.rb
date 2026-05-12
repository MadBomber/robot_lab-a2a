# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module A2A
    class RegistryTest < Minitest::Test
      def setup
        RobotLab::A2A::Registry.clear
      end

      def teardown
        RobotLab::A2A::Registry.clear
      end

      def new_entry
        RobotLab::A2A::Registry::Entry.new(
          thread: Thread.current,
          event_queue: Queue.new,
          answer_queue: Queue.new
        )
      end

      def test_size_is_zero_when_empty
        assert_equal 0, RobotLab::A2A::Registry.size
      end

      def test_size_reflects_registered_entries
        RobotLab::A2A::Registry.register('a', new_entry)
        RobotLab::A2A::Registry.register('b', new_entry)
        assert_equal 2, RobotLab::A2A::Registry.size
      end

      def test_fetch_returns_nil_for_unknown_id
        assert_nil RobotLab::A2A::Registry.fetch('nonexistent')
      end

      def test_clear_removes_all_entries
        RobotLab::A2A::Registry.register('x', new_entry)
        RobotLab::A2A::Registry.clear
        assert_equal 0, RobotLab::A2A::Registry.size
        assert_nil RobotLab::A2A::Registry.fetch('x')
      end

      def test_delete_returns_the_removed_entry
        entry = new_entry
        RobotLab::A2A::Registry.register('del', entry)
        result = RobotLab::A2A::Registry.delete('del')
        assert_equal entry, result
      end

      def test_concurrent_register_and_fetch
        entries = 20.times.map { new_entry }
        threads = entries.each_with_index.map do |entry, i|
          Thread.new { RobotLab::A2A::Registry.register("t#{i}", entry) }
        end
        threads.each(&:join)
        assert_equal 20, RobotLab::A2A::Registry.size
      end
    end
  end
end
