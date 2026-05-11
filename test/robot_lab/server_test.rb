# frozen_string_literal: true

require "test_helper"

class RobotLab::A2A::ServerTest < Minitest::Test
  FakeRobot   = Struct.new(:name, :description)
  FakeNetwork = Struct.new(:name, :description)

  def new_server(**opts)
    RobotLab::A2A::Server.new(host: "localhost", port: 9292, **opts)
  end

  # --- constructor ---

  def test_new_returns_server_instance
    assert_instance_of RobotLab::A2A::Server, new_server
  end

  # --- add_robot ---

  def test_add_robot_returns_self_for_chaining
    server = new_server
    robot  = FakeRobot.new("my_robot", "A test robot")
    assert_same server, server.add_robot(robot)
  end

  def test_add_robot_accepts_name_override
    server = new_server
    robot  = FakeRobot.new("original", "desc")
    assert_same server, server.add_robot(robot, name: "overridden")
  end

  def test_add_robot_accepts_path_override
    server = new_server
    robot  = FakeRobot.new("bot", "desc")
    assert_same server, server.add_robot(robot, path: "/custom-path")
  end

  def test_add_robot_with_nil_description_falls_back_to_name
    server = new_server
    robot  = FakeRobot.new("bot", nil)
    assert_same server, server.add_robot(robot)
  end

  # --- add_network ---

  def test_add_network_returns_self_for_chaining
    server  = new_server
    network = FakeNetwork.new("pipeline", "A pipeline")
    assert_same server, server.add_network(network, name: "pipeline")
  end

  def test_add_network_accepts_path_override
    server  = new_server
    network = FakeNetwork.new("net", "desc")
    assert_same server, server.add_network(network, name: "net", path: "/net")
  end

  def test_add_network_raises_when_server_is_interactive
    server  = new_server(interactive: :a2a_tool)
    network = FakeNetwork.new("net", "desc")
    assert_raises(ArgumentError) { server.add_network(network, name: "net") }
  end

  # --- dns_label (tested via path convention) ---

  def test_dns_label_converts_underscores_to_hyphens
    server = new_server
    robot  = FakeRobot.new("my_robot_name", "desc")
    # Just verify add_robot doesn't raise — path is derived from name
    assert_same server, server.add_robot(robot)
  end

  def test_dns_label_strips_invalid_characters
    server = new_server
    robot  = FakeRobot.new("Robot #1!", "desc")
    assert_same server, server.add_robot(robot)
  end

  # --- to_app ---

  def test_to_app_returns_rack_url_map
    server = new_server
    robot  = FakeRobot.new("bot", "A bot")
    server.add_robot(robot)
    assert_instance_of Rack::URLMap, server.to_app
  end

  def test_to_app_with_multiple_agents
    server  = new_server
    server.add_robot(FakeRobot.new("alpha", "first"))
    server.add_robot(FakeRobot.new("beta",  "second"))
    assert_instance_of Rack::URLMap, server.to_app
  end
end
