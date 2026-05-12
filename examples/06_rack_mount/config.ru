# frozen_string_literal: true

# config.ru — standalone Rack / Rails mount reference
#
# This file shows how to embed a RobotLab A2A agent inside any Rack-compatible
# server using server.to_app.  It is NOT used by the demo runner (which uses
# server.rb); it is here as a copy-paste reference.
#
# Run standalone with:
#   bundle exec rackup examples/06_rack_mount/config.ru -p 9292
#
# Mount inside a Rails app (config/routes.rb):
#   a2a = RobotLab::A2A::Server.new
#   a2a.add_robot(MyRobot.new)
#   mount a2a.to_app, at: '/'
#
# Mount inside a Sinatra app:
#   use Rack::URLMap, '/' => RobotLab::A2A::Server.new.add_robot(MyRobot.new).to_app

$LOAD_PATH.unshift File.expand_path('../../lib', __dir__)
require 'robot_lab/a2a'
require 'json'

class EchoRobot
  Result = Struct.new(:reply)
  def name        = 'echo_robot'
  def description = 'Echoes input back in uppercase with a character count'
  def run(input)
    text = input.strip
    Result.new("#{text.upcase}  [#{text.length} chars]")
  end
end

a2a = RobotLab::A2A::Server.new
a2a.add_robot(EchoRobot.new)

health = lambda do |_env|
  [200, { 'content-type' => 'application/json' }, [{ status: 'ok' }.to_json]]
end

run Rack::URLMap.new(
  '/health' => health,
  '/'       => a2a.to_app
)
