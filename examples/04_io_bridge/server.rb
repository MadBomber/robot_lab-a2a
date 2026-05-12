#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/04_io_bridge/server.rb
#
# Demonstrates :io_bridge interactive mode.
#
# IoBridge replaces robot.input and robot.output before each robot.run()
# call. Text written to @output is buffered; when the robot calls @input.gets,
# the buffer is emitted as an input_required A2A message and the call blocks
# until the client resumes the task. The robot thread then unblocks, receiving
# the answer as if a user had typed it at a terminal.
#
# Key point: QuoteRobot has NO knowledge of A2A. It reads and writes plain Ruby
# IO — the same code runs interactively in a terminal:
#
#   robot = QuoteRobot.new
#   robot.run('stoicism')        # prompts and reads from $stdin/$stdout
#
# Contrast with :a2a_tool, which requires the robot to call an injected tool.
# Use :io_bridge for existing robots that already use puts/gets directly.

require_relative '../common_config'

# ---------------------------------------------------------------------------
# Robot — standard Ruby IO; no mention of A2A, tools, or queues.
# attr_writer :input, :output lets RobotAdapter inject the IoBridge before run.
# Without injection, run() falls back to $stdin/$stdout (terminal mode).
# ---------------------------------------------------------------------------
class QuoteRobot
  Result = Struct.new(:reply)

  def name        = 'quote_robot'
  def description = 'Composes an inspirational quote addressed to the caller'

  attr_writer :input, :output

  def run(topic)
    out = @output || $stdout
    inp = @input  || $stdin

    out.puts "Who should I address this #{topic} quote to?"
    name = inp.gets.chomp

    Result.new(
      "#{name}: \"#{topic.capitalize} is not a destination — it is a way of travelling.\""
    )
  end
end

# ---------------------------------------------------------------------------
# Server — :io_bridge injects IoBridge as robot.input and robot.output.
# ---------------------------------------------------------------------------
server = RobotLab::A2A::Server.new(host: 'localhost', port: 9292, interactive: :io_bridge)
server.add_robot(QuoteRobot.new)

puts <<~HEREDOC
  Starting QuoteRobot on http://localhost:9292/quote-robot
  Interactive mode: :io_bridge  (plain IO replaced by IoBridge)
  Press Ctrl-C to stop.

HEREDOC

server.run
