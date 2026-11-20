# robot_lab-a2a

`robot_lab-a2a` exposes RobotLab robots and networks as [Agent2Agent (A2A)](https://google.github.io/A2A/) protocol agents over HTTP and Server-Sent Events. It bridges RobotLab's terminal-based `AskUser` tool to A2A's `input_required`/resume lifecycle, enabling multi-turn conversational flows without any terminal dependency. HTTP serving is delegated to the `simple_a2a` gem.

## Installation

```bash
bundle add robot_lab-a2a
```

Or add to your `Gemfile` manually:

```ruby
gem "robot_lab-a2a"
```

## Quick Start

### Sync robot (no user input)

```ruby
require "robot_lab/a2a"

robot = MyRobot.new  # any RobotLab::Robot subclass

RobotLab::A2A::Server.new(port: 9292)
  .add_robot(robot, name: "My Robot", description: "Does something useful")
  .run
```

### Interactive robot (multi-turn via AskUserTool)

```ruby
require "robot_lab/a2a"

robot = MyInteractiveRobot.new

RobotLab::A2A::Server.new(interactive: :a2a_tool, port: 9292)
  .add_robot(robot, name: "Interactive Robot", description: "Asks clarifying questions")
  .run
```

### Network pipeline

```ruby
require "robot_lab/a2a"

network = MyPipeline.new

RobotLab::A2A::Server.new(port: 9292)
  .add_network(network, name: "Pipeline", description: "Multi-stage pipeline")
  .run
```

## Running the Examples

From the repo root:

```bash
bundle exec ruby examples/run 01_sync_robot
bundle exec ruby examples/run 02_interactive_a2a_tool
bundle exec ruby examples/run 03_robot_network
```

Or from inside the `examples/` directory:

```bash
./run 01_sync_robot
```

Each example starts its own server. Use a second terminal or curl to interact with it. See [docs/examples.md](docs/examples.md) for expected output and two-turn client patterns.

## Documentation

Full documentation lives in [`docs/`](docs/):

- [Overview and architecture](docs/index.md)
- [Getting started](docs/getting-started.md)
- [Interactive modes](docs/interactive-modes.md)
- [Server API reference](docs/server-api.md)
- [Examples guide](docs/examples.md)

## Development

```bash
bin/setup        # install dependencies
rake test        # run the full test suite
asgard quality   # static analysis quality gates
asgard build     # build the gem package
```

Run a single test file:

```bash
ruby -Ilib -Itest test/robot_lab/a2a_test.rb
```

Run a single test by name:

```bash
ruby -Ilib -Itest test/robot_lab/registry_test.rb -n test_size_is_zero_when_empty
```

## License

MIT
