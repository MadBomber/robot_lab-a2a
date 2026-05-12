#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/06_rack_mount/client.rb
#
# Start the server first:
#   bundle exec ruby examples/06_rack_mount/server.rb
#
# Or run both together:
#   bundle exec ruby examples/run 06_rack_mount
#
# What this demo shows:
#
#   The A2A agent and a plain Rack endpoint live on the same server process.
#   The client exercises both, proving that non-A2A routes and A2A agent routes
#   coexist correctly when the agent is mounted via server.to_app.

require_relative '../common_config'
require 'net/http'
require 'json'

BASE_URL  = 'http://localhost:9292'
AGENT_URL = "#{BASE_URL}/echo-robot"

a2a_client = A2A.client(url: AGENT_URL)

def divider = puts('─' * 60)

# ---------------------------------------------------------------------------
# 1. Health check — plain HTTP GET to the non-A2A Rack endpoint
# ---------------------------------------------------------------------------
puts
puts '=== Health Check (plain Rack endpoint) ==='

health_response = Net::HTTP.get_response(URI("#{BASE_URL}/health"))
health_body     = JSON.parse(health_response.body) rescue {}

puts <<~HEREDOC
    Status code : #{health_response.code}
    Body        : #{health_response.body}

HEREDOC

divider

# ---------------------------------------------------------------------------
# 2. A2A agent — standard task send/receive
# ---------------------------------------------------------------------------
puts
puts '=== Agent Card ==='
card = a2a_client.agent_card
puts <<~HEREDOC
    Name:        #{card.name}
    Description: #{card.description}

HEREDOC

puts '=== Send Task ==='
task  = a2a_client.send_task(message: A2A::Models::Message.user('hello from rack mount'))
reply = task.artifacts.first&.parts&.first&.text || '(no reply)'

puts <<~HEREDOC
    State : #{task.status.state}
    Reply : #{reply}

HEREDOC

divider
puts

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
puts '=== Verification ==='

health_ok = health_response.code == '200'
status_ok = health_body['status'] == 'ok'
task_ok   = task.status.state == 'completed'
reply_ok  = reply.include?('HELLO')

puts <<~HEREDOC
    Health endpoint returned 200 : #{health_ok ? 'PASS' : 'FAIL'}
    Health body status is ok     : #{status_ok ? 'PASS' : 'FAIL'}
    A2A task completed           : #{task_ok   ? 'PASS' : 'FAIL'}
    A2A reply contains echo      : #{reply_ok  ? 'PASS' : 'FAIL'}

HEREDOC

all_ok = health_ok && status_ok && task_ok && reply_ok
puts(all_ok ? 'All assertions passed.' : 'One or more assertions failed.')
