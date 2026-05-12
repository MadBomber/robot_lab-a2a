#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/03_robot_network/client.rb
#
# Start the server first:
#   bundle exec ruby examples/03_robot_network/server.rb
#
# Or run both together:
#   bundle exec ruby examples/run 03_robot_network
#
# What this demo shows:
#
#   A RobotLab::Network (a pipeline of cooperating robots) exposed as a single
#   A2A agent via NetworkAdapter. The client sends raw text and receives output
#   that has passed through all three pipeline stages in sequence. From the A2A
#   protocol's point of view this is one agent with one task — the internal
#   multi-robot structure is completely invisible across the HTTP boundary.

require_relative '../common_config'

URL = 'http://localhost:9292/editorial-pipeline'

client = A2A.client(url: URL)

# ---------------------------------------------------------------------------
# 1. Discover the agent
# ---------------------------------------------------------------------------
puts '=== Agent Card ==='
card = client.agent_card
puts <<~HEREDOC
    Name:        #{card.name}
    Description: #{card.description}
    Skills:      #{card.skills.map(&:name).join(', ')}

HEREDOC

# ---------------------------------------------------------------------------
# 2. Send documents through the pipeline
# ---------------------------------------------------------------------------
documents = [
  'the quick brown fox jumps over the lazy dog',
  'ruby is a dynamic object-oriented programming language',
  'the agent2agent protocol enables robots to communicate over http'
]

puts '=== Pipeline Results ==='
results = documents.map do |doc|
  task   = client.send_task(message: A2A::Models::Message.user(doc))
  output = task.artifacts.first&.parts&.first&.text || '(no output)'

  puts <<~HEREDOC
    Input:  #{doc.inspect}
    Output: #{output.inspect}
    State:  #{task.status.state}

  HEREDOC
  { task: task, output: output }
end

# ---------------------------------------------------------------------------
# 3. Verify all pipeline stages ran
# ---------------------------------------------------------------------------
puts '=== Verification ==='
checks = results.map do |r|
  output = r[:output]
  completed  = r[:task].status.state == 'completed'
  analysed   = output.match?(/\[analysed:/i)
  formatted  = output.match?(/[A-Z]/)
  summarised = output.start_with?('SUMMARY')

  puts <<~HEREDOC
    completed  : #{completed  ? 'PASS' : 'FAIL'}
    analysed   : #{analysed   ? 'PASS' : 'FAIL'}
    formatted  : #{formatted  ? 'PASS' : 'FAIL'}
    summarised : #{summarised ? 'PASS' : 'FAIL'}

  HEREDOC

  completed && analysed && formatted && summarised
end

puts(checks.all? ? 'All pipeline checks passed.' : 'One or more checks failed.')
