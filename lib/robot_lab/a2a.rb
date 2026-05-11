# frozen_string_literal: true

require "robot_lab"
require "simple_a2a"
require "rack"

require_relative "a2a/version"
require_relative "a2a/registry"
require_relative "a2a/ask_user_tool"
require_relative "a2a/io_bridge"
require_relative "a2a/robot_adapter"
require_relative "a2a/network_adapter"
require_relative "a2a/server"

if defined?(RobotLab) && RobotLab.respond_to?(:register_extension)
  RobotLab.register_extension(:a2a, RobotLab::A2A)
end
