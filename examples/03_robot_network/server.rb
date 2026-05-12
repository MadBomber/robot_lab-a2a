#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/03_robot_network/server.rb
#
# Wraps a RobotLab-style network (a pipeline of robots) as a single A2A agent.
# The network processes the input through multiple stages in sequence and returns
# the final output. From the A2A client's perspective it looks like one agent.
#
# NetworkAdapter only supports :none (synchronous) mode. For interactive networks
# wrap individual robots with RobotAdapter instead.
#
# To use a real RobotLab::Network:
#   require "robot_lab"
#   network = RobotLab.create_network(name: "pipeline") do
#     step :analyst, analyst_robot, depends_on: :none
#     step :writer,  writer_robot,  depends_on: [:analyst]
#   end
#   server = RobotLab::A2A::Server.new
#   server.add_network(network, name: "pipeline")

require_relative '../common_config'

# ---------------------------------------------------------------------------
# Individual robots — each transforms the text in a distinct way.
# ---------------------------------------------------------------------------
class AnalyserRobot
  Result = Struct.new(:reply)
  def run(input) = Result.new("[analysed: #{input.split.length} words] #{input}")
end

class FormatterRobot
  Result = Struct.new(:reply)
  def run(input) = Result.new(input.gsub(/\b\w/, &:upcase))
end

class SummaryRobot
  Result = Struct.new(:reply)
  def run(input) = Result.new("SUMMARY → #{input}")
end

# ---------------------------------------------------------------------------
# Pipeline network — runs robots in sequence, passing output as the next input.
#
# Implements the interface expected by NetworkAdapter:
#   network.run(message: String) → object responding to #last_text_content
# ---------------------------------------------------------------------------
class EditorialPipeline
  NetworkResult = Struct.new(:last_text_content)

  STAGES = [AnalyserRobot, FormatterRobot, SummaryRobot].freeze

  def run(message:)
    output = STAGES.reduce(message) { |text, klass| klass.new.run(text).reply }
    NetworkResult.new(output)
  end
end

# ---------------------------------------------------------------------------
# Server — add_network requires an explicit name: for the agent card.
# The path defaults to "/editorial-pipeline" (DNS-safe label of the name).
# ---------------------------------------------------------------------------
server = RobotLab::A2A::Server.new(host: 'localhost', port: 9292)
server.add_network(
  EditorialPipeline.new,
  name: 'editorial_pipeline',
  description: 'Three-stage text pipeline: analyse → format → summarise'
)

puts <<~HEREDOC
  Starting EditorialPipeline on http://localhost:9292/editorial-pipeline
  Stages: AnalyserRobot → FormatterRobot → SummaryRobot
  Press Ctrl-C to stop.

HEREDOC

server.run
