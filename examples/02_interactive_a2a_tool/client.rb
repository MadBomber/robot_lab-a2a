#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/02_interactive_a2a_tool/client.rb
#
# Start the server first:
#   bundle exec ruby examples/02_interactive_a2a_tool/server.rb
#
# Or run both together:
#   bundle exec ruby examples/run 02_interactive_a2a_tool
#
# What this demo shows:
#
#   Turn 1 — client sends an initial topic.
#             The robot calls AskUserTool, which suspends the robot thread and
#             returns an input_required task containing the robot's question.
#
#   Turn 2 — client reads the question from the task status message and sends
#             a follow-up with task_id: pointing at the same task.
#             The adapter resumes the robot thread with the answer, the robot
#             completes, and the task reaches the "completed" state.
#
# Note: Turn 2 requires simple_a2a to route the follow-up to the waiting robot
# thread via a ResumeContext. This is supported in simple_a2a >= 0.4. With
# earlier versions Turn 1 still demonstrates the input_required suspension.

require_relative '../common_config'

URL = 'http://localhost:9292/personal-greeter'

client = A2A.client(url: URL)

def divider = puts('─' * 60)

# ---------------------------------------------------------------------------
# Discover the agent
# ---------------------------------------------------------------------------
puts
puts '=== Agent Card ==='
card = client.agent_card
puts "  Name:        #{card.name}"
puts "  Description: #{card.description}"
puts

divider

# ---------------------------------------------------------------------------
# Turn 1 — initial request; expect input_required
# ---------------------------------------------------------------------------
puts
puts '=== Turn 1: Initial request ==='
puts "  Sending topic: 'the A2A protocol'"
puts

task1 = client.send_task(message: A2A::Models::Message.user('the A2A protocol'))

state1   = task1.status.state
question = task1.status.message&.parts&.first&.text

puts "  Task ID: #{task1.id}"
puts "  State:   #{state1}"
puts "  Question: #{question}" if question
puts

if state1 != 'input_required'
  puts "Expected input_required — got #{state1.inspect}."
  puts 'The robot may not have an AskUserTool injected (check server interactive: mode).'
  exit 1
end

divider

# ---------------------------------------------------------------------------
# Turn 2 — answer the robot's question using the same task ID
# ---------------------------------------------------------------------------
puts
puts '=== Turn 2: Answer ==='
puts "  Answering: 'Alice'"
puts

begin
  task2 = client.send_task(
    message: A2A::Models::Message.user('Alice'),
    task_id: task1.id
  )

  state2    = task2.status.state
  reply     = task2.artifacts&.first&.parts&.first&.text
  new_task  = task2.id != task1.id # simple_a2a created a fresh task instead of resuming

  puts "  Task ID: #{task2.id}"
  puts "  State:   #{state2}"
  puts "  Reply:   #{reply}" if reply
  puts

  divider
  puts

  puts '=== Verification ==='
  if new_task
    puts '  Turn 1 returned input_required : PASS'
    puts '  Turn 2 skipped — server created a new task instead of resuming'
    puts '        (simple_a2a >= 0.4 required for full two-turn resume)'
    puts
    puts 'Turn 1 passed. Upgrade simple_a2a to >= 0.4 for the full two-turn demo.'
  else
    turn1_ok = state1 == 'input_required'
    turn2_ok = state2 == 'completed'
    reply_ok = reply&.include?('Alice')

    puts "  Turn 1 returned input_required : #{turn1_ok ? 'PASS' : 'FAIL'}"
    puts "  Turn 2 completed after answer  : #{turn2_ok ? 'PASS' : 'FAIL'}"
    puts "  Reply mentions the caller name : #{reply_ok ? 'PASS' : 'FAIL'}"
    puts

    all_ok = turn1_ok && turn2_ok && reply_ok
    puts(all_ok ? 'All assertions passed.' : 'One or more assertions failed.')
  end
rescue A2A::Error => e
  puts "  A2A error on Turn 2: #{e.message}"
  puts
  puts '=== Verification ==='
  puts "  Turn 1 returned input_required : #{state1 == 'input_required' ? 'PASS' : 'FAIL'}"
  puts '  Turn 2 skipped (server does not yet support resume via task_id)'
  puts
  puts 'Turn 1 passed. Upgrade simple_a2a to >= 0.4 for full two-turn demo.'
end
