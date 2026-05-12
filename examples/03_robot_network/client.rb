#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/03_robot_network/client.rb
#
# Start the server first:
#   bundle exec ruby examples/03_robot_network/server.rb
#
# Or run both together:
#   bundle exec ruby examples/run 03_robot_network

require_relative '../common_config'

URL = 'http://localhost:9292/editorial-pipeline'

client = A2A.client(url: URL)

# ---------------------------------------------------------------------------
# 1. Discover the agent
# ---------------------------------------------------------------------------
puts '=== Agent Card ==='
card = client.agent_card
puts "  Name:        #{card.name}"
puts "  Description: #{card.description}"
puts "  Skills:      #{card.skills.map(&:name).join(', ')}"
puts

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

  puts "  Input:  #{doc.inspect}"
  puts "  Output: #{output.inspect}"
  puts "  State:  #{task.status.state}"
  puts
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

  puts "  completed  : #{completed  ? 'PASS' : 'FAIL'}"
  puts "  analysed   : #{analysed   ? 'PASS' : 'FAIL'}"
  puts "  formatted  : #{formatted  ? 'PASS' : 'FAIL'}"
  puts "  summarised : #{summarised ? 'PASS' : 'FAIL'}"
  puts

  completed && analysed && formatted && summarised
end

puts(checks.all? ? 'All pipeline checks passed.' : 'One or more checks failed.')
