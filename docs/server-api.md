# Server API Reference

`RobotLab::A2A::Server` is a fluent builder. Every mutating method returns `self` so calls can be chained.

## Constructor

```ruby
RobotLab::A2A::Server.new(
  host:        "localhost",  # String  — bind address
  port:        9292,         # Integer — TCP port
  storage:     nil,          # Object  — task storage backend (simple_a2a compatible); nil uses in-memory default
  interactive: :none         # Symbol  — default interactive mode for all registered adapters
)
```

| Parameter | Type | Default | Notes |
|---|---|---|---|
| `host` | `String` | `"localhost"` | Passed through to `simple_a2a` / Falcon |
| `port` | `Integer` | `9292` | TCP port to listen on |
| `storage` | Object / nil | `nil` | Pluggable task persistence; defaults to an in-memory store |
| `interactive` | `Symbol` | `:none` | Applies to all adapters unless overridden per-registration |

Valid `interactive` values: `:none`, `:a2a_tool`, `:io_bridge`. See [Interactive Modes](interactive-modes.md) for details.

## `add_robot`

```ruby
server.add_robot(
  robot,
  name:        nil,        # String — human-readable agent name; defaults to robot.name
  description: nil,        # String — agent capability description; defaults to robot.description
  path:        nil         # String — URL path segment; derived from name if nil
) → self
```

Wraps `robot` in a `RobotAdapter` using the server's `interactive` setting and registers it with `simple_a2a`.

**`robot` must respond to:**

- `robot.name` → `String`
- `robot.description` → `String`
- `robot.run(text)` → object responding to `.reply`
- For `:a2a_tool`: `robot.local_tools` → mutable `Array` (backed by `@local_tools`)
- For `:io_bridge`: `robot.input=` and `robot.output=`

**Path defaulting:** If `path:` is omitted, it is derived from `name` by applying the DNS label conversion rule (see below). Example: `name: "My Robot"` → path `/my-robot`.

## `add_network`

```ruby
server.add_network(
  network,
  name:        required,   # String — human-readable agent name
  description: nil,        # String — agent capability description; defaults to name
  path:        nil         # String — URL path segment; derived from name if nil
) → self
```

Wraps `network` in a `NetworkAdapter`, always constructed with `interactive: :none`. If the server's own `interactive` setting is anything other than `:none`, `add_network` raises `ArgumentError` instead of silently ignoring it — networks do not support interactive modes. Wrap individual robots with `RobotAdapter` (via `add_robot`) for interactive flows.

**`network` must respond to:**

- `network.run(message: text)` → object responding to `.last_text_content`

**Path defaulting:** Same DNS label conversion as `add_robot`.

## `add_robot` — optional keyword details

`name:` and `description:` default to `robot.name` and `robot.description` when omitted. `path:` always defaults to the DNS label of the name used.

## `run`

```ruby
server.run
```

Starts the Falcon HTTP server (blocking). Host and port are set in the constructor. Does not return until the server is stopped.

## `to_app`

```ruby
app = server.to_app  # → Rack::URLMap
```

Returns a `Rack::URLMap` instead of starting a server. Use this to embed `robot_lab-a2a` inside an existing Rack application such as Rails or Puma.

Example `config.ru`:

```ruby
require "robot_lab/a2a"
require_relative "my_robot"

robot = MyRobot.new
a2a = RobotLab::A2A::Server.new
        .add_robot(robot, name: "Assistant", description: "General assistant")

run Rack::URLMap.new(
  "/"     => MyRailsApp,
  "/a2a"  => a2a.to_app
)
```

## DNS label conversion rule

Agent names are converted to RFC 1123-compatible path segments:

1. Convert to lowercase.
2. Replace underscores with hyphens.
3. Drop any character that is not an ASCII letter, digit, or hyphen.
4. Strip leading/trailing hyphens.

Examples:

| Name | Path |
|---|---|
| `"My Robot"` | `/my-robot` |
| `"order_processor"` | `/order-processor` |
| `"GPT-4 Agent!"` | `/gpt-4-agent` |
