#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/04_io_bridge/client.rb
#
# Start the server first:
#   bundle exec ruby examples/04_io_bridge/server.rb
#
# Or run both together:
#   bundle exec ruby examples/run 04_io_bridge
#
# What this demo shows:
#
#   Turn 1 — client sends a topic ('stoicism').
#             QuoteRobot writes the prompt to @output (buffered by IoBridge)
#             then calls @input.gets. IoBridge flushes the buffer as the
#             input_required message and blocks. The A2A task enters the
#             input_required state with the prompt as its status message.
#
#   Turn 2 — client sends a follow-up with task_id: pointing at the same task.
#             IoBridge pushes the answer to the robot thread, unblocking gets.
#             The robot completes and the task reaches the "completed" state.
#
# Note: Turn 2 requires simple_a2a >= 0.3.1 to route the follow-up to the
# waiting robot thread via a ResumeContext. With earlier versions Turn 1 still
# demonstrates the input_required suspension.

require_relative '../common_config'

URL = 'http://localhost:9292/quote-robot'

client = A2A.client(url: URL)

def divider = puts('─' * 60)

# ---------------------------------------------------------------------------
# Discover the agent
# ---------------------------------------------------------------------------
puts
puts '=== Agent Card ==='
card = client.agent_card
puts <<~HEREDOC
    Name:        #{card.name}
    Description: #{card.description}

HEREDOC

divider

# ---------------------------------------------------------------------------
# Turn 1 — initial request; expect input_required
# ---------------------------------------------------------------------------
puts <<~HEREDOC

  === Turn 1: Initial request ===
    Sending topic: 'stoicism'

HEREDOC

task1 = client.send_task(message: A2A::Models::Message.user('stoicism'))

state1  = task1.status.state
prompt  = task1.status.message&.parts&.first&.text

puts "  Task ID: #{task1.id}"
puts "  State:   #{state1}"
puts "  Prompt:  #{prompt}" if prompt
puts

if state1 != 'input_required'
  puts "Expected input_required — got #{state1.inspect}."
  puts 'Check that the server is running with interactive: :io_bridge.'
  exit 1
end

divider

# ---------------------------------------------------------------------------
# Turn 2 — answer the robot's question using the same task ID
# ---------------------------------------------------------------------------
puts <<~HEREDOC

  === Turn 2: Answer ===
    Answering: 'Ada'

HEREDOC

begin
  task2 = client.send_task(
    message: A2A::Models::Message.user('Ada'),
    task_id: task1.id
  )

  state2   = task2.status.state
  reply    = task2.artifacts&.first&.parts&.first&.text
  new_task = task2.id != task1.id

  puts "  Task ID: #{task2.id}"
  puts "  State:   #{state2}"
  puts "  Reply:   #{reply}" if reply
  puts

  divider
  puts

  puts '=== Verification ==='
  if new_task
    puts <<~HEREDOC
        Turn 1 returned input_required : PASS
        Turn 2 skipped — server created a new task instead of resuming
              (simple_a2a >= 0.3.1 required for full two-turn resume)

      Turn 1 passed. Upgrade simple_a2a to >= 0.3.1 for the full two-turn demo.
    HEREDOC
  else
    turn1_ok = state1 == 'input_required'
    turn2_ok = state2 == 'completed'
    reply_ok = reply&.include?('Ada')

    puts <<~HEREDOC
        Turn 1 returned input_required : #{turn1_ok ? 'PASS' : 'FAIL'}
        Turn 2 completed after answer  : #{turn2_ok ? 'PASS' : 'FAIL'}
        Reply addresses the caller     : #{reply_ok ? 'PASS' : 'FAIL'}

    HEREDOC

    all_ok = turn1_ok && turn2_ok && reply_ok
    puts(all_ok ? 'All assertions passed.' : 'One or more assertions failed.')
  end
rescue A2A::Error => e
  puts <<~HEREDOC
      A2A error on Turn 2: #{e.message}

    === Verification ===
      Turn 1 returned input_required : #{state1 == 'input_required' ? 'PASS' : 'FAIL'}
      Turn 2 skipped (server does not yet support resume via task_id)

    Turn 1 passed. Upgrade simple_a2a to >= 0.3.1 for the full two-turn demo.
  HEREDOC
end
