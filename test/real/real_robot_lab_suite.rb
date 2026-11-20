# frozen_string_literal: true

# Regression suite that runs against the REAL robot_lab gem.
#
# The main suite loads test/support/robot_lab.rb (a stub) in place of the gem,
# so bugs that only show up with real RobotLab::Robot / RobotLab::Network
# objects are invisible there. This file is deliberately not named *_test.rb:
# test/robot_lab/real_robot_lab_test.rb runs it in a child process, where the
# stub is not on the load path.
#
# No LLM calls are made — Robot#invoke_ask (the model round-trip) is replaced
# on each robot instance.

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)

require 'robot_lab/a2a'
require 'minitest/autorun'
require 'stringio'

class RealRobotLabSuite < Minitest::Test
  class StopBeforeModel < StandardError; end

  def setup
    RobotLab::A2A::Registry.clear
  end

  def teardown
    RobotLab::A2A::Registry.clear
  end

  # --- B1: NetworkAdapter with a real RobotLab::Network -----------------------

  def test_network_adapter_reads_reply_from_real_network_result
    robot = build_robot('stage')
    robot.define_singleton_method(:run) do |*_args, **_opts|
      RobotLab::RobotResult.new(
        robot_name: 'stage',
        output: [RobotLab::TextMessage.new(role: 'assistant', content: 'network says hi')]
      )
    end
    network = RobotLab.create_network(name: 'pipeline') { task :stage, robot, depends_on: :none }
    context = new_context

    RobotLab::A2A::NetworkAdapter.new(network).call(context)

    assert_equal 'completed', context.task.state
    assert_equal 'network says hi', context.task.artifacts.first.parts.first.text
  end

  # --- B2 + B3: :a2a_tool with a real RobotLab::Robot -------------------------

  def test_a2a_tool_offers_injected_tool_to_the_model
    robot = build_robot('asker', local_tools: [RobotLab::AskUser])
    seen  = capture_run_state(robot)

    run_adapter(robot, :a2a_tool)

    assert(seen[:chat_tools].any?(RobotLab::A2A::AskUserTool), 'AskUserTool was not offered to the model')
    refute(seen[:chat_tools].any?(RobotLab::AskUser), 'terminal AskUser should be displaced during the run')
  end

  def test_a2a_tool_restores_displaced_ask_user
    robot    = build_robot('asker', local_tools: [RobotLab::AskUser])
    original = robot.local_tools.dup
    capture_run_state(robot)

    run_adapter(robot, :a2a_tool)

    assert_equal original, robot.local_tools
    assert_instance_of RobotLab::AskUser, robot.local_tools.first
  end

  # --- B2 + B3: :io_bridge with a real RobotLab::Robot ------------------------

  def test_io_bridge_offers_core_ask_user_and_bridges_io
    robot = build_robot('asker', local_tools: [RobotLab::AskUser])
    seen  = capture_run_state(robot)

    run_adapter(robot, :io_bridge)

    assert(seen[:chat_tools].any?(RobotLab::AskUser), 'core AskUser was not offered to the model')
    assert_instance_of RobotLab::A2A::IoBridge, seen[:input]
    assert_instance_of RobotLab::A2A::IoBridge, seen[:output]
  end

  def test_io_bridge_restores_previous_streams
    robot        = build_robot('asker')
    input        = StringIO.new
    output       = StringIO.new
    robot.input  = input
    robot.output = output
    capture_run_state(robot)

    run_adapter(robot, :io_bridge)

    assert_same input,  robot.input
    assert_same output, robot.output
  end

  # --- B4: failure text travels as an A2A Message -----------------------------

  def test_failed_task_carries_a_message_that_survives_serialisation
    robot = build_robot('asker')
    capture_run_state(robot)

    task      = run_adapter(robot, :a2a_tool)
    roundtrip = A2A::Models::Task.from_hash(JSON.parse(JSON.generate(task.to_h)))

    assert_equal 'failed', task.state
    assert_instance_of A2A::Models::Message, task.status.message
    assert_equal 'stop before model', roundtrip.status.message.text_content
  end

  private

  def build_robot(name, **)
    RobotLab.build(name: name, system_prompt: 'You are a test robot.', model: 'gpt-4o-mini', **)
  end

  # Replaces the model round-trip: records what the robot would have sent,
  # then aborts the run so no request leaves the process.
  def capture_run_state(robot)
    seen = {}
    robot.define_singleton_method(:invoke_ask) do |**_opts|
      seen[:chat_tools] = chat.tools.values
      seen[:input]      = input
      seen[:output]     = output
      raise StopBeforeModel, 'stop before model'
    end
    seen
  end

  def new_context
    task = A2A::Models::Task.new(status: A2A::Models::TaskStatus.new(state: 'submitted'))
    A2A::Server::Context.new(
      task: task,
      message: A2A::Models::Message.user('hello'),
      storage: A2A::Storage::Memory.new,
      event_router: A2A::Server::TaskBroadcast.new
    )
  end

  # Runs one interactive call and waits for the robot thread's teardown.
  def run_adapter(robot, mode)
    context = new_context
    task_id = context.task.id
    RobotLab::A2A::RobotAdapter.new(robot, interactive: mode).call(context)

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 2
    sleep 0.005 while RobotLab::A2A::Registry.fetch(task_id) && Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    context.task
  end
end
