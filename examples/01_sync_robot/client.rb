#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/01_sync_robot/client.rb
#
# Start the server first:
#   bundle exec ruby examples/01_sync_robot/server.rb
#
# Or run both together:
#   bundle exec ruby examples/run 01_sync_robot
#
# What this demo shows:
#
#   Discovery  — client.agent_card fetches the agent's name, description, and
#                skills declared by the robot and published over A2A.
#
#   Task send  — client.send_task dispatches a user message and returns a
#                completed task whose artifact holds the robot's reply.
#
#   Task list  — client.list_tasks returns all tasks the agent has processed,
#                demonstrating the A2A task-store query interface.
#
#   Task get   — client.get_task(id) retrieves a specific completed task by ID,
#                confirming the reply is durable and addressable after the fact.

require_relative '../common_config'

URL = 'http://localhost:9292/echo-robot'

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
# 2. Send tasks and inspect replies
# ---------------------------------------------------------------------------
messages = [
  'hello from robot_lab-a2a',
  'the agent2agent protocol',
  'RobotLab makes multi-robot workflows easy'
]

puts '=== Sending Tasks ==='
task_ids = messages.map do |text|
  task  = client.send_task(message: A2A::Models::Message.user(text))
  reply = task.artifacts.first&.parts&.first&.text || '(no reply)'
  puts <<~HEREDOC
    [#{task.status.state}]
      sent: #{text.inspect}
      got:  #{reply.inspect}

  HEREDOC
  task.id
end

# ---------------------------------------------------------------------------
# 3. List all tasks
# ---------------------------------------------------------------------------
puts '=== Task List ==='
all_tasks = client.list_tasks
all_tasks.each { |t| puts "  #{t.id}  state=#{t.status.state}" }
puts "  Total: #{all_tasks.size}"
puts

# ---------------------------------------------------------------------------
# 4. Retrieve a task by ID
# ---------------------------------------------------------------------------
puts '=== Retrieve Task ==='
retrieved = client.get_task(task_ids.first)
puts <<~HEREDOC
    id:    #{retrieved.id}
    state: #{retrieved.status.state}
    reply: #{retrieved.artifacts.first&.parts&.first&.text.inspect}

HEREDOC

# ---------------------------------------------------------------------------
# 5. Verify
# ---------------------------------------------------------------------------
puts '=== Verification ==='
all_completed = task_ids.all? do |id|
  client.get_task(id).status.state == 'completed'
end
puts(all_completed ? 'All tasks completed. PASS' : 'Some tasks did not complete. FAIL')
