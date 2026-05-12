#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/05_multi_agent/server.rb
#
# Demonstrates multiple A2A agents on a single server using the fluent
# builder API with explicit path overrides.
#
# Each robot is mounted at its own URL path and exposed as an independent
# A2A agent with its own agent card. An A2A client discovers and addresses
# each agent separately — they share the same server process but are
# completely independent from the protocol's point of view.
#
# Server builder pattern:
#   server.add_robot(robot_a, path: '/headline')
#         .add_robot(robot_b, path: '/tags')
#         .run

require_relative '../common_config'

# ---------------------------------------------------------------------------
# HeadlineRobot — turns a passage of text into a punchy headline.
# Registered at /headline via an explicit path: override.
# ---------------------------------------------------------------------------
class HeadlineRobot
  Result = Struct.new(:reply)

  def name        = 'headline_robot'
  def description = 'Condenses input text into a short, punchy headline'

  def run(input)
    words    = input.strip.split
    headline = words.first(6).map(&:capitalize).join(' ')
    headline += '…' if words.length > 6
    Result.new(headline)
  end
end

# ---------------------------------------------------------------------------
# TagRobot — extracts hashtag-style keywords from a passage of text.
# Registered at /tags via an explicit path: override.
# ---------------------------------------------------------------------------
class TagRobot
  Result = Struct.new(:reply)

  def name        = 'tag_robot'
  def description = 'Extracts hashtag keywords from input text'

  def run(input)
    tags = input.downcase
                .scan(/\b[a-z]{4,}\b/)
                .uniq
                .first(5)
                .map { |w| "##{w}" }
                .join('  ')
    Result.new(tags)
  end
end

# ---------------------------------------------------------------------------
# Server — two robots, two paths, one server process.
# The fluent add_robot calls return self so they can be chained.
# ---------------------------------------------------------------------------
server = RobotLab::A2A::Server.new(host: 'localhost', port: 9292)
server.add_robot(HeadlineRobot.new, path: '/headline')
      .add_robot(TagRobot.new,      path: '/tags')

puts <<~HEREDOC
  Starting multi-agent server on http://localhost:9292
    /headline  — HeadlineRobot
    /tags      — TagRobot
  Press Ctrl-C to stop.

HEREDOC

server.run
