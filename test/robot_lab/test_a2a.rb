# frozen_string_literal: true

require "test_helper"

class RobotLab::TestA2A < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RobotLab::A2A::VERSION
  end

  def test_extension_registers_with_robot_lab
    assert RobotLab.extension_loaded?(:a2a)
    assert_equal RobotLab::A2A, RobotLab.extension(:a2a)
  end

  def test_registry_stores_and_retrieves_entries
    entry = RobotLab::A2A::Registry::Entry.new(
      thread:       Thread.current,
      event_queue:  Queue.new,
      answer_queue: Queue.new
    )
    RobotLab::A2A::Registry.register("task-123", entry)
    assert_equal entry, RobotLab::A2A::Registry.fetch("task-123")
  ensure
    RobotLab::A2A::Registry.delete("task-123")
  end

  def test_registry_delete_removes_entry
    entry = RobotLab::A2A::Registry::Entry.new(
      thread:       Thread.current,
      event_queue:  Queue.new,
      answer_queue: Queue.new
    )
    RobotLab::A2A::Registry.register("task-del", entry)
    RobotLab::A2A::Registry.delete("task-del")
    assert_nil RobotLab::A2A::Registry.fetch("task-del")
  end

  def test_server_builds_without_error
    server = RobotLab::A2A::Server.new(host: "localhost", port: 9292)
    assert_instance_of RobotLab::A2A::Server, server
  end

  def test_network_adapter_rejects_interactive_modes
    network = Object.new
    assert_raises(ArgumentError) do
      RobotLab::A2A::NetworkAdapter.new(network, interactive: :acp_tool)
    end
  end

  def test_robot_adapter_rejects_invalid_mode
    robot = Object.new
    assert_raises(ArgumentError) do
      RobotLab::A2A::RobotAdapter.new(robot, interactive: :invalid)
    end
  end
end
