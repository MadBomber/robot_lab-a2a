#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/01_sync_robot/server.rb
#
# Wraps a plain Ruby robot object as an A2A agent in :none (synchronous) mode.
# The robot receives the task message, processes it, and returns a reply in a
# single call — no interactive turns, no LLM required.
#
# Swap EchoRobot for a real RobotLab.build(...) robot to connect a live LLM.

require_relative '../common_config'

# ---------------------------------------------------------------------------
# Robot — any object that responds to #name, #description, and #run(input).
# run() must return an object with a #reply method.
# ---------------------------------------------------------------------------
class EchoRobot
  Result = Struct.new(:reply)

  def name        = 'echo_robot'
  def description = 'Transforms every message: upcases it and reports character count'

  def run(input)
    text = input.strip
    Result.new("#{text.upcase}  [#{text.length} chars, processed by EchoRobot]")
  end
end

# ---------------------------------------------------------------------------
# Build and start the A2A server.
#
# RobotLab::A2A::Server wraps each robot in a RobotAdapter, builds an AgentCard
# from the robot's name and description, and delegates HTTP serving to simple_a2a.
# ---------------------------------------------------------------------------
server = RobotLab::A2A::Server.new(host: 'localhost', port: 9292)
server.add_robot(EchoRobot.new)

puts 'Starting EchoRobot on http://localhost:9292/echo-robot'
puts 'Press Ctrl-C to stop.'
puts

server.run
