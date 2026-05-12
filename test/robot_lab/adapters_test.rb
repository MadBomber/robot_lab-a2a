# frozen_string_literal: true

require 'test_helper'

# ── Shared doubles ────────────────────────────────────────────────────────────

module AdapterTestHelpers
  MockResult = Struct.new(:reply)

  class MockTask
    attr_reader :state, :artifacts, :last_message, :id

    def initialize(id)
      @id        = id
      @state     = :pending
      @artifacts = []
    end

    def start! = (@state = :running)

    def complete!(**opts)
      (@state = :completed
       @artifacts = opts[:artifacts] || [])
    end

    def fail!(**opts)
      (@state = :failed
       @last_message = opts[:message])
    end

    def cancel! = (@state = :cancelled)

    def require_input!(**opts)
      (@state = :input_required
       @last_message = opts[:message])
    end
  end

  class MockMessage
    def initialize(text) = (@text = text)
    def text_content     = @text
  end

  class MockContext
    attr_reader :task, :message, :emissions

    def initialize(task:, message:)
      @task      = task
      @message   = message
      @emissions = []
    end

    def emit_status(**opts) = @emissions << opts
  end

  # Satisfies the is_a?(::A2A::Server::ResumeContext) check in run_interactive
  class MockResumeContext < MockContext
    def resume_message = MockMessage.new('resume answer')

    def is_a?(klass)
      return true if klass == ::A2A::Server::ResumeContext

      super
    end
  end

  # ── Robot doubles ─────────────────────────────────────────────────────────

  # Simple robot — returns immediately with no interaction
  class MockRobot
    def name        = 'mock_robot'
    def description = 'A mock robot'
    def run(input)  = MockResult.new("reply to: #{input}")
  end

  # Robot with local_tools support (required for :a2a_tool injection)
  class MockInteractiveRobot
    def initialize = (@local_tools = [])
    attr_reader :local_tools

    def name                  = 'interactive_robot'
    def description           = 'interactive'
    def run(_input)           = MockResult.new('done')
  end

  # Robot that calls the injected AskUserTool once, then returns
  class MockAskingRobot
    def initialize = (@local_tools = [])
    attr_reader :local_tools

    def name          = 'asking_robot'
    def description   = 'asks'

    def run(_input)
      tool = @local_tools.find { |t| t.is_a?(RobotLab::A2A::AskUserTool) }
      tool&.execute(question: 'What is your name?')
      MockResult.new('done after ask')
    end
  end

  # Robot that raises during run
  class MockErrorRobot
    def initialize = (@local_tools = [])
    attr_reader :local_tools

    def name          = 'error_robot'
    def description   = 'always errors'
    def run(_input)   = raise 'simulated robot error'
  end

  # Robot with IO accessors for :io_bridge mode — returns without reading input
  class MockIoBridgeRobot
    attr_accessor :input, :output

    def initialize = (@local_tools = [])
    attr_reader :local_tools

    def name          = 'io_robot'
    def description   = 'uses io'
    def run(_input)   = MockResult.new('io done')
  end

  # Robot with IO accessors that calls @input.gets — triggers the bridge
  class MockIoBridgeAskingRobot
    attr_accessor :input, :output

    def initialize = (@local_tools = [])
    attr_reader :local_tools

    def name          = 'io_asking_robot'
    def description   = 'asks via io'

    def run(_input)
      @input&.gets
      MockResult.new('io ask done')
    end
  end

  # ── Network doubles ───────────────────────────────────────────────────────

  class MockNetworkResult
    def last_text_content = 'network reply'
  end

  class MockNetwork
    def run(**) = MockNetworkResult.new
  end
end

# ── RobotAdapter — :none mode ─────────────────────────────────────────────────

module RobotLab
  module A2A
    class RobotAdapterNoneTest < Minitest::Test
      include AdapterTestHelpers

      def setup
        RobotLab::A2A::Registry.clear
      end

      def teardown
        RobotLab::A2A::Registry.clear
      end

      def test_valid_modes_instantiate_without_error
        robot = MockRobot.new
        %i[none a2a_tool io_bridge].each do |mode|
          assert_instance_of RobotLab::A2A::RobotAdapter,
                             RobotLab::A2A::RobotAdapter.new(robot, interactive: mode)
        end
      end

      def test_call_none_completes_task
        adapter = RobotLab::A2A::RobotAdapter.new(MockRobot.new, interactive: :none)
        task    = MockTask.new('none-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)

        assert_equal :completed, task.state
        refute_empty task.artifacts
      end

      def test_call_none_emits_status_twice
        adapter = RobotLab::A2A::RobotAdapter.new(MockRobot.new, interactive: :none)
        task    = MockTask.new('none-2')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hi'))

        adapter.call(ctx)

        assert_equal 2, ctx.emissions.size
        assert ctx.emissions.last[:final]
      end

      def test_cancel_kills_registered_thread
        adapter  = RobotLab::A2A::RobotAdapter.new(MockRobot.new, interactive: :none)
        task_id  = 'cancel-1'
        thread   = Thread.new { sleep 60 }
        entry    = RobotLab::A2A::Registry::Entry.new(
          thread: thread, event_queue: Queue.new, answer_queue: Queue.new
        )
        RobotLab::A2A::Registry.register(task_id, entry)
        task = MockTask.new(task_id)
        ctx  = MockContext.new(task: task, message: MockMessage.new('x'))

        adapter.cancel(ctx)
        wait_until { !thread.alive? }

        assert_nil RobotLab::A2A::Registry.fetch(task_id)
        refute thread.alive?
      ensure
        thread&.kill
      end

      def test_cancel_with_no_registered_entry_does_not_raise
        adapter = RobotLab::A2A::RobotAdapter.new(MockRobot.new, interactive: :none)
        task    = MockTask.new('no-such')
        ctx     = MockContext.new(task: task, message: MockMessage.new('x'))

        assert_silent { adapter.cancel(ctx) }
      end
    end
  end
end

# ── RobotAdapter — :a2a_tool mode ────────────────────────────────────────────

module RobotLab
  module A2A
    class RobotAdapterA2AToolTest < Minitest::Test
      include AdapterTestHelpers

      def setup
        RobotLab::A2A::Registry.clear
      end

      def teardown
        RobotLab::A2A::Registry.clear
      end

      # --- :done path ---

      def test_done_path_completes_task
        adapter = RobotLab::A2A::RobotAdapter.new(MockInteractiveRobot.new, interactive: :a2a_tool)
        task    = MockTask.new('a2a-done-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)

        assert_equal :completed, task.state
        assert_equal 2, ctx.emissions.size
        assert ctx.emissions.last[:final]
      end

      def test_done_path_restores_tools
        robot   = MockInteractiveRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :a2a_tool)
        task    = MockTask.new('a2a-done-2')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)
        wait_until { robot.instance_variable_get(:@_a2a_injected_tool).nil? }

        assert_empty(robot.local_tools.grep(RobotLab::A2A::AskUserTool))
      end

      # --- :ask path ---

      def test_ask_path_requires_input
        robot   = MockAskingRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :a2a_tool)
        task    = MockTask.new('a2a-ask-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)

        assert_equal :input_required, task.state
        assert_equal 2, ctx.emissions.size
        assert ctx.emissions.last[:final]
        refute_nil RobotLab::A2A::Registry.fetch('a2a-ask-1')
      ensure
        cleanup_thread('a2a-ask-1')
      end

      def test_ask_path_stores_entry_in_registry
        robot   = MockAskingRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :a2a_tool)
        task    = MockTask.new('a2a-ask-2')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)

        entry = RobotLab::A2A::Registry.fetch('a2a-ask-2')
        refute_nil entry
        assert_instance_of RobotLab::A2A::Registry::Entry, entry
      ensure
        cleanup_thread('a2a-ask-2')
      end

      # --- resume path ---

      def test_resume_after_ask_completes_task
        robot   = MockAskingRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :a2a_tool)
        task    = MockTask.new('a2a-resume-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)
        assert_equal :input_required, task.state

        resume_ctx = MockResumeContext.new(task: task, message: MockMessage.new('ignored'))
        adapter.call(resume_ctx)

        assert_equal :completed, task.state
        assert resume_ctx.emissions.last[:final]
      end

      def test_resume_without_active_session_fails_task
        robot   = MockRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :a2a_tool)
        task    = MockTask.new('a2a-no-session')
        ctx     = MockResumeContext.new(task: task, message: MockMessage.new('x'))

        adapter.call(ctx)

        assert_equal :failed, task.state
        assert_match 'No active session', task.last_message
        assert ctx.emissions.last[:final]
      end

      # --- :error path ---

      def test_error_path_fails_task
        robot   = MockErrorRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :a2a_tool)
        task    = MockTask.new('a2a-error-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)

        assert_equal :failed, task.state
        assert_match 'simulated robot error', task.last_message
        assert ctx.emissions.last[:final]
      end

      private

      def cleanup_thread(task_id)
        entry = RobotLab::A2A::Registry.fetch(task_id)
        if entry&.thread&.alive?
          entry.answer_queue.push('__cleanup__')
          entry.thread.join(2)
        end
        RobotLab::A2A::Registry.delete(task_id)
      end
    end
  end
end

# ── RobotAdapter — :io_bridge mode ───────────────────────────────────────────

module RobotLab
  module A2A
    class RobotAdapterIoBridgeTest < Minitest::Test
      include AdapterTestHelpers

      def setup
        RobotLab::A2A::Registry.clear
      end

      def teardown
        RobotLab::A2A::Registry.clear
      end

      # --- :done path ---

      def test_done_path_completes_task
        adapter = RobotLab::A2A::RobotAdapter.new(MockIoBridgeRobot.new, interactive: :io_bridge)
        task    = MockTask.new('io-done-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)

        assert_equal :completed, task.state
        assert ctx.emissions.last[:final]
      end

      def test_done_path_clears_io_after_teardown
        robot   = MockIoBridgeRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :io_bridge)
        task    = MockTask.new('io-done-2')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)
        wait_until { robot.input.nil? && robot.output.nil? }

        assert_nil robot.input
        assert_nil robot.output
      end

      # --- :ask path ---

      def test_ask_path_requires_input
        robot   = MockIoBridgeAskingRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :io_bridge)
        task    = MockTask.new('io-ask-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)

        assert_equal :input_required, task.state
      ensure
        cleanup_thread('io-ask-1')
      end

      # --- resume path ---

      def test_resume_after_ask_completes_task
        robot   = MockIoBridgeAskingRobot.new
        adapter = RobotLab::A2A::RobotAdapter.new(robot, interactive: :io_bridge)
        task    = MockTask.new('io-resume-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('hello'))

        adapter.call(ctx)
        assert_equal :input_required, task.state

        resume_ctx = MockResumeContext.new(task: task, message: MockMessage.new('x'))
        adapter.call(resume_ctx)

        assert_equal :completed, task.state
      end

      private

      def cleanup_thread(task_id)
        entry = RobotLab::A2A::Registry.fetch(task_id)
        if entry&.thread&.alive?
          entry.answer_queue.push('__cleanup__')
          entry.thread.join(2)
        end
        RobotLab::A2A::Registry.delete(task_id)
      end
    end
  end
end

# ── NetworkAdapter ────────────────────────────────────────────────────────────

module RobotLab
  module A2A
    class NetworkAdapterTest < Minitest::Test
      include AdapterTestHelpers

      def test_none_mode_instantiates
        assert_instance_of RobotLab::A2A::NetworkAdapter,
                           RobotLab::A2A::NetworkAdapter.new(MockNetwork.new, interactive: :none)
      end

      def test_call_completes_task
        adapter = RobotLab::A2A::NetworkAdapter.new(MockNetwork.new, interactive: :none)
        task    = MockTask.new('net-1')
        ctx     = MockContext.new(task: task, message: MockMessage.new('process this'))

        adapter.call(ctx)

        assert_equal :completed, task.state
        refute_empty task.artifacts
      end

      def test_call_emits_status_twice
        adapter = RobotLab::A2A::NetworkAdapter.new(MockNetwork.new, interactive: :none)
        task    = MockTask.new('net-2')
        ctx     = MockContext.new(task: task, message: MockMessage.new('go'))

        adapter.call(ctx)

        assert_equal 2, ctx.emissions.size
        assert ctx.emissions.last[:final]
      end
    end
  end
end
