# Getting Started

## Requirements

- Ruby >= 4.0.9
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

The gem also depends on `simple_a2a`. For interactive resume support (`input_required`/resume lifecycle), you need a build of `simple_a2a` that includes `ResumeContext` (the bundled examples name `simple_a2a` >= 0.3.1). If your local copy is newer than the released gem, use a path dependency for that too:

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

  # robot_lab-a2a calls run(text) and expects a result with a .reply method
end
```

### 2. Start the server

```ruby
# server.rb
require "robot_lab/a2a"
require_relative "my_robot"

robot = GreeterRobot.new

RobotLab::A2A::Server.new(port: 7000)
  .add_robot(robot, name: "Greeter", description: "Returns a greeting")
  .run
```

```bash
bundle exec ruby server.rb
# serves http://localhost:7000 until interrupted (the server prints nothing on startup)
```

### 3. Send a task

The server exposes each robot at its DNS-label path. `GreeterRobot` registered as `"Greeter"` becomes `/greeter`.

Requests are JSON-RPC 2.0 POSTs to that path; the A2A method name goes in the body:

```bash
curl -X POST http://localhost:7000/greeter \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": "1", "method": "tasks/send",
       "params": {"message": {"role": "user", "parts": [{"text": "Hello!"}]}}}'
```

`tasks/send` returns a single JSON-RPC response whose `result` is the task: `result.status.state` is `"completed"` and the robot's reply is the text part of `result.artifacts[0]` (the artifact is named `"reply"`). To receive SSE status events instead, use the `tasks/sendSubscribe` method with the same `params`.

### 4. Inspect the agent card

Every registered agent exposes its agent card at `agentCard` under its path (via `simple_a2a`):

```bash
curl http://localhost:7000/greeter/agentCard
```

## What's next

- [Interactive Modes](interactive-modes.md) — enable multi-turn conversations with `:a2a_tool` or `:io_bridge`
- [Server API](server-api.md) — full reference for `Server.new`, `add_robot`, `add_network`, `run`, and `to_app`
