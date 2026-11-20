# frozen_string_literal: true

module RobotLab
  module A2A
    # Wraps a RobotLab::Robot as an A2A AgentExecutor.
    #
    # Pass an instance as the executor: when building an A2A server:
    #
    #   adapter = RobotAdapter.new(robot, interactive: :none)
    #   A2A.server(agent_card: card, executor: adapter).run
    #
    # interactive modes:
    #   :none      — robot runs sync; AskUser would block stdin (not recommended)
    #   :a2a_tool  — A2A::AskUserTool replaces AskUser; Thread+Queue bridge
    #   :io_bridge — IoBridge replaces robot.input/output; Thread+Queue bridge
    #
    # Interactive modes keep the robot thread alive between A2A INPUT_REQUIRED
    # and resume. Only works with in-process (Memory) storage.
    #
    # :reek:DataClump -- robot plus its event/answer queue pair thread through
    # the per-mode injection helpers; a wrapper object would outlive its one use.
    # :reek:RepeatedConditional -- @interactive is the adapter's mode switch;
    # run, setup and teardown each dispatch on it once.
    class RobotAdapter < ::A2A::Server::AgentExecutor
      VALID_MODES = %i[none a2a_tool io_bridge].freeze

      def initialize(robot, interactive: :none)
        super()
        unless VALID_MODES.include?(interactive)
          raise ArgumentError, "interactive must be one of #{VALID_MODES.inspect}"
        end

        @robot       = robot
        @interactive = interactive
      end

      def call(context)
        input_text = context.message.text_content
        task_id    = context.task.id

        case @interactive
        when :none
          run_simple(context, input_text)
        when :a2a_tool, :io_bridge
          run_interactive(context, input_text, task_id)
        end
      end

      def cancel(context)
        task_id = context.task.id
        entry   = Registry.fetch(task_id)
        if entry
          entry.thread.kill
          Registry.delete(task_id)
        end
        super
      end

      private

      # ── :none mode ────────────────────────────────────────────

      # :reek:FeatureEnvy -- executor lifecycle: drives start/complete/emit on
      # the request context handed to it by the A2A server.
      def run_simple(context, input_text)
        context.task.start!
        context.emit_status

        reply    = @robot.run(input_text).reply
        artifact = ::A2A::Models::Artifact.new(
          parts: [::A2A::Models::Part.text(reply.to_s)],
          name: 'reply'
        )
        context.task.complete!(artifacts: [artifact])
        context.emit_status(final: true)
      end

      # ── interactive modes ─────────────────────────────────────

      # :reek:FeatureEnvy -- resume-vs-fresh dispatch on the request context;
      # the fail/emit calls belong to the A2A task lifecycle, not another home.
      def run_interactive(context, input_text, task_id)
        if context.is_a?(::A2A::Server::ResumeContext)
          entry = Registry.fetch(task_id)
          if entry
            entry.answer_queue.push(context.resume_message.text_content)
            monitor_task(context, entry, task_id)
          else
            context.task.fail!(message: 'No active session found for resumed task')
            context.emit_status(final: true)
          end
        else
          start_interactive_run(context, input_text, task_id)
        end
      end

      # :reek:TooManyStatements -- linear bootstrap of one interactive run:
      # build queues, start task, spawn robot thread, register, then monitor.
      def start_interactive_run(context, input_text, task_id)
        event_queue  = Queue.new
        answer_queue = Queue.new
        robot        = @robot

        context.task.start!
        context.emit_status

        thread = Thread.new do
          setup_interactive_mode(robot, event_queue, answer_queue)
          reply = robot.run(input_text).reply
          event_queue.push({ type: :done, reply: reply })
        rescue StandardError => e
          event_queue.push({ type: :error, error: e })
        ensure
          teardown_interactive_mode(robot)
          Registry.delete(task_id)
        end

        entry = Registry::Entry.new(
          thread: thread,
          event_queue: event_queue,
          answer_queue: answer_queue
        )
        Registry.register(task_id, entry)

        monitor_task(context, entry, task_id)
      end

      def monitor_task(context, entry, _task_id)
        event = entry.event_queue.pop
        task  = context.task
        case event[:type]
        when :ask
          task.require_input!(message: event[:prompt])
        when :done
          artifact = ::A2A::Models::Artifact.new(
            parts: [::A2A::Models::Part.text(event[:reply].to_s)],
            name: 'reply'
          )
          task.complete!(artifacts: [artifact])
        when :error
          task.fail!(message: event[:error].message)
        end
        context.emit_status(final: true)
      end

      # ── interactive setup / teardown ──────────────────────────

      def setup_interactive_mode(robot, event_queue, answer_queue)
        case @interactive
        when :a2a_tool  then inject_ask_user_tool(robot, event_queue, answer_queue)
        when :io_bridge then inject_io_bridge(robot, event_queue, answer_queue)
        end
      end

      def teardown_interactive_mode(robot)
        case @interactive
        when :a2a_tool
          restore_tools(robot)
        when :io_bridge
          robot.input  = nil
          robot.output = nil
        end
      end

      def inject_ask_user_tool(robot, event_queue, answer_queue)
        tool = AskUserTool.new(robot: robot)
        tool.event_queue  = event_queue
        tool.answer_queue = answer_queue

        without_ask_user = robot.local_tools.reject do |t|
          t.is_a?(RobotLab::AskUser) || t.is_a?(AskUserTool)
        end
        robot.instance_variable_set(:@local_tools, without_ask_user + [tool])
        robot.instance_variable_set(:@_a2a_injected_tool, tool)
      end

      def restore_tools(robot)
        injected = robot.instance_variable_get(:@_a2a_injected_tool)
        return unless injected

        cleaned = robot.local_tools.reject { |t| t.equal?(injected) }
        robot.instance_variable_set(:@local_tools, cleaned)
        robot.remove_instance_variable(:@_a2a_injected_tool)
      end

      def inject_io_bridge(robot, event_queue, answer_queue)
        bridge = IoBridge.new(event_queue: event_queue, answer_queue: answer_queue)
        robot.input  = bridge
        robot.output = bridge
      end
    end
  end
end
