# Interactive Modes

## Why interactive matters

RobotLab's `AskUser` tool blocks the robot thread and reads from a terminal. That works fine for CLI scripts but breaks completely in an HTTP server: there is no terminal, and the HTTP request has already returned by the time the robot needs an answer.

`robot_lab-a2a` solves this by converting blocking terminal prompts into A2A `input_required` events. The robot thread pauses on a Ruby `Queue`. The HTTP layer serialises the prompt as an SSE event to the A2A client. When the client sends a resume request, the answer is placed onto the queue and the robot thread continues — all without any terminal.

Three modes are available. Choose based on how your robot is implemented.

## `:none` mode

The default. The robot receives the initial text message, runs to completion, and returns a single reply. No user interaction occurs during execution.

```ruby
RobotLab::A2A::Server.new                        # interactive: :none is the default
  .add_robot(robot, name: "Summariser", description: "Summarises text")
  .run(port: 7000)
```

**Robot interface required:** `robot.run(text)` returns a result responding to `.reply`.

Use `:none` when your robot never calls `AskUser` or reads from stdin.

## `:a2a_tool` mode

The server injects an `AskUserTool` instance into `robot.local_tools` before the robot thread starts, and removes it on teardown. `AskUserTool` is a drop-in replacement for `RobotLab::AskUser` that uses `Queue` instead of `$stdin`.

**Turn 1 — initial request:**

```bash
curl -X POST http://localhost:7000/my-robot/tasks/send \
  -H "Content-Type: application/json" \
  -d '{"message": {"role": "user", "parts": [{"text": "Plan a trip"}]}}'
```

The server starts the robot on a new Thread, keyed in `Registry` by the A2A task ID. When the robot calls `AskUser`, `AskUserTool#execute`:

1. Pushes `{type: :ask, prompt: "Where do you want to go?"}` onto `event_queue`.
2. Blocks on `answer_queue`.

The SSE stream delivers an `input_required` event to the client containing the prompt text and the task ID.

**Turn 2 — resume:**

```bash
curl -X POST http://localhost:7000/my-robot/tasks/send \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": "<task-id-from-turn-1>",
    "message": {"role": "user", "parts": [{"text": "Paris"}]}
  }'
```

`simple_a2a` routes this to the resume handler. The server looks up the task in `Registry`, places `"Paris"` onto `answer_queue`, and the blocked `AskUserTool#execute` returns `"Paris"` to the robot. The robot continues. If it calls `AskUser` again, the cycle repeats. When the robot finishes, a `task_complete` event closes the SSE stream.

**Setup:**

```ruby
RobotLab::A2A::Server.new(interactive: :a2a_tool)
  .add_robot(robot, name: "Planner", description: "Plans trips interactively")
  .run(port: 7000)
```

**Robot interface required:**

- `robot.run(text)` — entry point.
- `robot.local_tools` — mutable `Array` that the server prepends `AskUserTool` to. The instance variable is `@local_tools`.

**Important:** Interactive resume requires a build of `simple_a2a` that includes `ResumeContext` support. See [Getting Started — Installation](getting-started.md#installation) for the path dependency pattern.

## `:io_bridge` mode

For robots that communicate via raw Ruby IO (`puts`/`gets`) rather than the `AskUser` tool. The server replaces `robot.input` and `robot.output` with an `IoBridge` instance before starting the robot thread, and restores the originals on teardown.

`IoBridge` behaviour:

- **Writes** (`write`, `puts`, `print`) — accumulate into an internal buffer.
- **`gets`** — flushes the buffer as an `input_required` SSE event (the buffered text becomes the prompt), then blocks on `answer_queue` until the A2A client resumes. The answer is returned from `gets` to the robot.

The two-turn client pattern is identical to `:a2a_tool`.

```ruby
RobotLab::A2A::Server.new(interactive: :io_bridge)
  .add_robot(robot, name: "IO Robot", description: "Uses gets/puts for interaction")
  .run(port: 7000)
```

**Robot interface required:**

- `robot.input=` / `robot.output=` — settable IO attributes.
- The robot must use `@input.gets` and `@output.puts` (or equivalent) rather than `$stdin`/`$stdout` directly.

**Important:** Interactive resume requires `simple_a2a` with `ResumeContext` support.

## Choosing a mode

| Mode | Robot interface required | Typical use case |
|---|---|---|
| `:none` | `robot.run(text) → result.reply` | Fully autonomous robots with no user prompts |
| `:a2a_tool` | `robot.run(text)` + mutable `robot.local_tools` | Robots that use `RobotLab::AskUser` as a tool |
| `:io_bridge` | `robot.run(text)` + settable `robot.input=` / `robot.output=` | Robots that interact via raw stdin/stdout streams |

When in doubt, start with `:none`. Upgrade to `:a2a_tool` if your robot uses `AskUser`, or `:io_bridge` if it uses raw IO.
