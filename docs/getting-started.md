# Getting Started

## Requirements

- Ruby >= 3.2
- The `robot_lab` gem (provides `RobotLab::Robot` and `RobotLab::Network`)
- Bundler

## Installation

### As a gem dependency

Add to your `Gemfile`:

```ruby
gem "robot_lab-a2a"
```

Then run:

```bash
bundle install
```

### As a local path dependency (for development)

If you are working directly in this repo or have a local checkout of `robot_lab-a2a`:

```ruby
# Gemfile
gem "robot_lab-a2a", path: "../robot_lab-a2a"
```

The gem also depends on `simple_a2a`. For interactive resume support (`input_required`/resume lifecycle), you need a build of `simple_a2a` that includes `ResumeContext`. If your local copy is newer than the released gem, use a path dependency for that too:

```ruby
gem "simple_a2a", path: "../simple_a2a"
```

## Sync Robot (5 minutes)

### 1. Define your robot

```ruby
# my_robot.rb
require "robot_lab"

class GreeterRobot < RobotLab::Robot
  def initialize
    super(
      name: "Greeter",
      description: "Returns a greeting for any input",
      model: "gpt-4o-mini"
    )
  end

  # robot_lab calls run(text) and expects a result with a .reply method
end
```

### 2. Start the server

```ruby
# server.rb
require "robot_lab/a2a"
require_relative "my_robot"

robot = GreeterRobot.new

RobotLab::A2A::Server.new
  .add_robot(robot, name: "Greeter", description: "Returns a greeting")
  .run(port: 7000)
```

```bash
bundle exec ruby server.rb
# => Listening on http://0.0.0.0:7000
```

### 3. Send a task

The server exposes each robot at its DNS-label path. `GreeterRobot` registered as `"Greeter"` becomes `/greeter`.

```bash
curl -X POST http://localhost:7000/greeter/tasks/send \
  -H "Content-Type: application/json" \
  -d '{"message": {"role": "user", "parts": [{"text": "Hello!"}]}}'
```

The response is a stream of SSE events ending with a `task_complete` event whose payload contains the robot's reply.

### 4. Inspect the agent card

Every registered agent exposes its capabilities at `/.well-known/agent.json` (via `simple_a2a`):

```bash
curl http://localhost:7000/greeter/.well-known/agent.json
```

## What's next

- [Interactive Modes](interactive-modes.md) — enable multi-turn conversations with `:a2a_tool` or `:io_bridge`
- [Server API](server-api.md) — full reference for `Server.new`, `add_robot`, `add_network`, `run`, and `to_app`
