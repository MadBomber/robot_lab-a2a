#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: bundle exec ruby examples/06_rack_mount/server.rb
#
# Demonstrates server.to_app — embedding A2A agents inside a larger Rack app.
#
# server.run       — starts a dedicated Falcon server for A2A agents only.
# server.to_app    — returns a Rack::URLMap that can be composed with other
#                    Rack middleware and mounted in any Rack-compatible server
#                    (Rails, Sinatra, Puma, Falcon, etc.).
#
# This demo composes the A2A agent with a /health JSON endpoint, runs the
# combined Rack app using the same Falcon runner simple_a2a uses internally.
#
# In a Rails application the equivalent is:
#
#   # config/routes.rb
#   mount RobotLab::A2A::Server.new.add_robot(my_robot).to_app, at: '/'
#
# See config.ru in this directory for the standalone Rack equivalent.

require_relative '../common_config'
require 'json'

# ---------------------------------------------------------------------------
# Robot — simple sync robot, identical role to EchoRobot in 01_sync_robot.
# The interesting part here is how the server is wired up, not the robot.
# ---------------------------------------------------------------------------
class EchoRobot
  Result = Struct.new(:reply)

  def name        = 'echo_robot'
  def description = 'Echoes input back in uppercase with a character count'

  def run(input)
    text = input.strip
    Result.new("#{text.upcase}  [#{text.length} chars]")
  end
end

# ---------------------------------------------------------------------------
# Build the A2A Rack app via to_app.
# ---------------------------------------------------------------------------
a2a = RobotLab::A2A::Server.new(host: 'localhost', port: 9292)
a2a.add_robot(EchoRobot.new)

a2a_app = a2a.to_app   # returns a Rack::URLMap — composable with any Rack app

# ---------------------------------------------------------------------------
# Compose with a /health endpoint to simulate a real multi-purpose app.
# ---------------------------------------------------------------------------
health = lambda do |_env|
  body = { status: 'ok', agents: ['echo_robot'] }.to_json
  [200, { 'content-type' => 'application/json' }, [body]]
end

combined_app = Rack::URLMap.new(
  '/health' => health,
  '/'       => a2a_app
)

puts <<~HEREDOC
  Starting combined Rack app on http://localhost:9292
    /health     — JSON health check (plain Rack lambda)
    /echo-robot — A2A EchoRobot (via server.to_app)
  Press Ctrl-C to stop.

HEREDOC

# Run the composed Rack app with the same Falcon runner simple_a2a uses.
A2A::Server::FalconRunner.new(combined_app, host: 'localhost', port: 9292).run
