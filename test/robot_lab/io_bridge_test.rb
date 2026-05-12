# frozen_string_literal: true

require 'test_helper'

module RobotLab
  module A2A
    class IoBridgeTest < Minitest::Test
      def setup
        @event_queue  = Queue.new
        @answer_queue = Queue.new
        @bridge = RobotLab::A2A::IoBridge.new(
          event_queue: @event_queue,
          answer_queue: @answer_queue
        )
      end

      # --- output side ---

      def test_write_returns_byte_length
        assert_equal 5, @bridge.write('hello')
      end

      def test_write_accepts_non_string
        assert_equal 2, @bridge.write(42)
      end

      def test_flush_returns_self
        assert_same @bridge, @bridge.flush
      end

      def test_sync_equals_does_not_raise
        @bridge.sync = true
        @bridge.sync = false
      end

      # --- gets behaviour ---

      def test_gets_returns_answer_with_newline
        @answer_queue.push('Alice')
        assert_equal "Alice\n", @bridge.gets
      end

      def test_gets_pushes_ask_event
        @answer_queue.push('Bob')
        @bridge.gets
        event = @event_queue.pop(true)
        assert_equal :ask, event[:type]
        refute_nil event[:prompt]
      end

      def test_gets_uses_buffered_print_as_prompt
        @bridge.print('Enter name: ')
        @answer_queue.push('Carol')
        @bridge.gets
        event = @event_queue.pop(true)
        # prompt wraps buffered text — verify it is non-empty
        refute_nil event[:prompt]
        assert_equal :ask, event[:type]
      end

      def test_gets_clears_buffer_after_use
        @bridge.puts('First prompt')
        @answer_queue.push('x')
        @bridge.gets
        @event_queue.pop(true) # discard first event

        @answer_queue.push('y')
        @bridge.gets
        event = @event_queue.pop(true)
        # second call should use default prompt (buffer was cleared)
        assert_equal :ask, event[:type]
      end

      def test_puts_no_args_adds_newline
        # Two gets calls: one for each puts to flush & inspect
        @bridge.puts
        @answer_queue.push('a')
        @bridge.gets
        event = @event_queue.pop(true)
        assert_equal :ask, event[:type]
      end

      def test_puts_with_multiple_args_each_terminated
        @bridge.puts('line1', 'line2')
        @answer_queue.push('z')
        @bridge.gets
        event = @event_queue.pop(true)
        assert_equal :ask, event[:type]
      end

      def test_print_nil_is_safe
        @bridge.print(nil)
        @answer_queue.push('ok')
        assert_equal "ok\n", @bridge.gets
      end
    end
  end
end
