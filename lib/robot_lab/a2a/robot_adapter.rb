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

        reply    = run_robot(@robot, input_text).reply
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
            fail_task(context.task, 'No active session found for resumed task')
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
          interactive_run(robot, input_text, event_queue, answer_queue)
        ensure
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

      # Body of the robot thread: set up the mode, run the robot, report the
      # outcome on event_queue, and always put the robot back as it was.
      def interactive_run(robot, input_text, event_queue, answer_queue)
        saved = setup_interactive_mode(robot, event_queue, answer_queue)
        reply = run_robot(robot, input_text).reply
        event_queue.push({ type: :done, reply: reply })
      rescue StandardError => e
        event_queue.push({ type: :error, error: e })
      ensure
        teardown_interactive_mode(robot, saved)
      end

      # :reek:FeatureEnvy -- translates one robot-thread event into a task transition.
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
          fail_task(task, event[:error].message)
        end
        context.emit_status(final: true)
      end

      def fail_task(task, text)
        task.fail!(message: failure_message(text))
      end

      # TaskStatus#message is an A2A Message, so failure text is wrapped in one.
      # :reek:UtilityFunction -- pure text-to-Message conversion.
      def failure_message(text)
        ::A2A::Models::Message.agent(text.to_s)
      end

      # ── running the robot ─────────────────────────────────────

      # RobotLab::Robot#run defaults to tools: :none, which sends the model no
      # tools at all. Ask for the robot's attached tools so the injected
      # AskUserTool (or core AskUser under :io_bridge) is actually offered.
      # Duck-typed robots whose #run takes only the input are called as before.
      # :reek:FeatureEnvy -- dispatches on the robot's #run signature; the robot is the subject.
      def run_robot(robot, input_text)
        accepts_tools_keyword?(robot) ? robot.run(input_text, tools: :inherit) : robot.run(input_text)
      end

      # :reek:UtilityFunction -- pure signature inspection of the robot's #run.
      def accepts_tools_keyword?(robot)
        robot.method(:run).parameters.any? do |type, name|
          type == :keyrest || (%i[key keyreq].include?(type) && name == :tools)
        end
      end

      # ── interactive setup / teardown ──────────────────────────

      # Returns the robot state it displaced, for teardown_interactive_mode.
      def setup_interactive_mode(robot, event_queue, answer_queue)
        case @interactive
        when :a2a_tool  then inject_ask_user_tool(robot, event_queue, answer_queue)
        when :io_bridge then inject_io_bridge(robot, event_queue, answer_queue)
        end
      end

      # saved is nil when setup raised before anything was displaced.
      def teardown_interactive_mode(robot, saved)
        return unless saved

        case @interactive
        when :a2a_tool  then restore_tools(robot, saved)
        when :io_bridge then restore_io(robot, saved)
        end
      end

      # Swaps any AskUser / AskUserTool for a queue-backed AskUserTool.
      # @return [Array] the robot's local_tools as they were before injection
      def inject_ask_user_tool(robot, event_queue, answer_queue)
        tool = AskUserTool.new(robot: robot)
        tool.event_queue  = event_queue
        tool.answer_queue = answer_queue

        original         = robot.local_tools
        without_ask_user = original.reject do |t|
          t.is_a?(RobotLab::AskUser) || t.is_a?(AskUserTool)
        end
        robot.instance_variable_set(:@local_tools, without_ask_user + [tool])
        original
      end

      # :reek:UtilityFunction -- puts back the tool list inject_ask_user_tool returned.
      def restore_tools(robot, original)
        robot.instance_variable_set(:@local_tools, original)
      end

      # @return [Hash] the robot's previous :input and :output streams
      def inject_io_bridge(robot, event_queue, answer_queue)
        saved  = { input: current_io(robot, :input), output: current_io(robot, :output) }
        bridge = IoBridge.new(event_queue: event_queue, answer_queue: answer_queue)
        robot.input  = bridge
        robot.output = bridge
        saved
      end

      # :reek:UtilityFunction -- puts back the streams inject_io_bridge returned.
      def restore_io(robot, saved)
        robot.input  = saved[:input]
        robot.output = saved[:output]
      end

      # Robots need only expose input=/output=; a missing reader means "unset".
      # :reek:UtilityFunction -- pure optional-reader lookup.
      # :reek:ManualDispatch -- the reader is optional on duck-typed robots.
      def current_io(robot, stream)
        robot.respond_to?(stream) ? robot.public_send(stream) : nil
      end
    end
  end
end
