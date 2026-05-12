#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/02_interactive_a2a_tool/server.rb
#
# Demonstrates :a2a_tool interactive mode.
#
# RobotLab::A2A::RobotAdapter injects an AskUserTool into the robot's local_tools
# before calling robot.run(). When the robot calls that tool, the adapter suspends
# the robot thread and returns an input_required task to the caller. A subsequent
# resume call (from an A2A client that supports task resume) unblocks the thread
# and allows the robot to finish.
#
# This demo shows the first half of that flow: the robot correctly enters
# input_required when the injected tool is called. Full end-to-end resume
# requires an A2A client that issues a tasks/send with the original task ID
# (supported by simple_a2a >= 0.4).
#
# To use a real LLM robot instead:
#   require "robot_lab"
#   robot = RobotLab.build(name: "greeter", system_prompt: "You are a friendly greeter...")
#   # Add RobotLab::AskUser to the robot's tools so the LLM can ask questions.
#   server = RobotLab::A2A::Server.new(interactive: :a2a_tool)
#   server.add_robot(robot)

require_relative '../common_config'

# ---------------------------------------------------------------------------
# Robot — calls the injected AskUserTool to pause and ask the caller a question.
#
# In a real RobotLab robot the LLM decides when to call AskUser. Here we call it
# directly to keep the demo self-contained.
# ---------------------------------------------------------------------------
class PersonalGreeterRobot
  Result = Struct.new(:reply)

  def initialize
    @local_tools = []
  end

  def name        = 'personal_greeter'
  def description = 'Asks your name before composing a personalised greeting'
  attr_reader :local_tools

  def run(topic)
    ask_tool = @local_tools.find { |t| t.is_a?(RobotLab::A2A::AskUserTool) }

    name = if ask_tool
             ask_tool.execute(question: 'What is your name?')
           else
             'stranger'
           end

    Result.new("Hello, #{name}! You wanted to know about: #{topic}")
  end
end

# ---------------------------------------------------------------------------
# Server — :a2a_tool mode injects AskUserTool before each robot.run() call.
# ---------------------------------------------------------------------------
server = RobotLab::A2A::Server.new(host: 'localhost', port: 9292, interactive: :a2a_tool)
server.add_robot(PersonalGreeterRobot.new)

puts 'Starting PersonalGreeterRobot on http://localhost:9292/personal-greeter'
puts 'Interactive mode: :a2a_tool  (AskUserTool injection)'
puts 'Press Ctrl-C to stop.'
puts

server.run
