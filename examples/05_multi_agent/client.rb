#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/05_multi_agent/client.rb
#
# Start the server first:
#   bundle exec ruby examples/05_multi_agent/server.rb
#
# Or run both together:
#   bundle exec ruby examples/run 05_multi_agent
#
# What this demo shows:
#
#   Two independent A2A clients, each pointing at a different agent path on
#   the same server. Each agent has its own agent card and processes the same
#   input text in a completely different way. From the A2A protocol's point of
#   view they are separate agents — the shared server process is invisible.

require_relative '../common_config'

BASE_URL     = 'http://localhost:9292'
HEADLINE_URL = "#{BASE_URL}/headline"
TAGS_URL     = "#{BASE_URL}/tags"

headline_client = A2A.client(url: HEADLINE_URL)
tags_client     = A2A.client(url: TAGS_URL)

def divider = puts('─' * 60)

# ---------------------------------------------------------------------------
# Discover both agents
# ---------------------------------------------------------------------------
puts
puts '=== Agent Cards ==='
headline_card = headline_client.agent_card
tags_card     = tags_client.agent_card

puts <<~HEREDOC
    /headline  #{headline_card.name}: #{headline_card.description}
    /tags      #{tags_card.name}: #{tags_card.description}

HEREDOC

divider

# ---------------------------------------------------------------------------
# Send the same text to both agents
# ---------------------------------------------------------------------------
INPUT = 'the agent2agent protocol enables robots to collaborate over HTTP'

puts <<~HEREDOC

  === Sending to both agents ===
    Input: #{INPUT.inspect}

HEREDOC

headline_task = headline_client.send_task(message: A2A::Models::Message.user(INPUT))
tags_task     = tags_client.send_task(message: A2A::Models::Message.user(INPUT))

headline_reply = headline_task.artifacts.first&.parts&.first&.text || '(no reply)'
tags_reply     = tags_task.artifacts.first&.parts&.first&.text     || '(no reply)'

puts <<~HEREDOC
    HeadlineRobot [#{headline_task.status.state}]
      #{headline_reply}

    TagRobot [#{tags_task.status.state}]
      #{tags_reply}

HEREDOC

divider
puts

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
puts '=== Verification ==='

headline_ok  = headline_task.status.state == 'completed'
tags_ok      = tags_task.status.state == 'completed'
distinct_ok  = headline_reply != tags_reply
headline_cap = headline_reply.match?(/\A[A-Z]/)
tags_hash    = tags_reply.include?('#')

puts <<~HEREDOC
    HeadlineRobot completed    : #{headline_ok  ? 'PASS' : 'FAIL'}
    TagRobot completed         : #{tags_ok      ? 'PASS' : 'FAIL'}
    Responses are distinct     : #{distinct_ok  ? 'PASS' : 'FAIL'}
    Headline starts capitalised: #{headline_cap ? 'PASS' : 'FAIL'}
    Tags contain hash symbols  : #{tags_hash    ? 'PASS' : 'FAIL'}

HEREDOC

all_ok = headline_ok && tags_ok && distinct_ok && headline_cap && tags_hash
puts(all_ok ? 'All assertions passed.' : 'One or more assertions failed.')
