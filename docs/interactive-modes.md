# Interactive Modes

## Why interactive matters

RobotLab's `AskUser` tool blocks the robot thread and reads from a terminal. That works fine for CLI scripts but breaks completely in an HTTP server: there is no terminal, and the HTTP request has already returned by the time the robot needs an answer.

`robot_lab-a2a` solves this by converting blocking terminal prompts into A2A `input_required` events. The robot thread pauses on a Ruby `Queue`. The HTTP layer returns the prompt to the A2A client as the status message of an `input_required` task. When the client sends a resume request, the answer is placed onto the queue and the robot thread continues — all without any terminal.

Three modes are available. Choose based on how your robot is implemented.

## `:none` mode

The default. The robot receives the initial text message, runs to completion, and returns a single reply. No user interaction occurs during execution.

```ruby
RobotLab::A2A::Server.new(port: 7000)            # interactive: :none is the default
  .add_robot(robot, name: "Summariser", description: "Summarises text")
  .run
```

**Robot interface required:** `robot.run(text)` returns a result responding to `.reply`. If `run` accepts a `tools:` keyword (as `RobotLab::Robot#run` does), the adapter passes `tools: :inherit` in every mode so the robot's attached tools are offered to the model.

Use `:none` when your robot never calls `AskUser` or reads from stdin.

## `:a2a_tool` mode

The adapter injects an `AskUserTool` instance into `robot.local_tools` at the start of the robot thread (taking the place of any `RobotLab::AskUser` already there), and restores the robot's original tool list on teardown. `AskUserTool` is a drop-in replacement for `RobotLab::AskUser` that uses `Queue` instead of `$stdin`.

**Turn 1 — initial request:**

```bash
curl -X POST http://localhost:7000/planner \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": "1", "method": "tasks/send",
       "params": {"message": {"role": "user", "parts": [{"text": "Plan a trip"}]}}}'
```

The server starts the robot on a new Thread, keyed in `Registry` by the A2A task ID. When the robot calls `AskUser`, `AskUserTool#execute`:

1. Pushes `{type: :ask, prompt: <agent message "Where do you want to go?">}` onto `event_queue`.
2. Blocks on `answer_queue`.

The `tasks/send` response is the task in state `input_required`: `result.id` is the task ID and `result.status.message` carries the prompt text.

**Turn 2 — resume:**

```bash
curl -X POST http://localhost:7000/planner \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc": "2.0", "id": "2", "method": "tasks/send",
       "params": {
         "id": "<task-id-from-turn-1>",
         "message": {"role": "user", "parts": [{"text": "Paris"}]}
       }}'
```

Because `params.id` names an `input_required` task, `simple_a2a` hands the executor a `ResumeContext` (resume is only available through `tasks/send`; `tasks/sendSubscribe` always starts a new task). The adapter looks up the task in `Registry`, places `"Paris"` onto `answer_queue`, and the blocked `AskUserTool#execute` returns `"Paris"` to the robot. The robot continues. If it calls `AskUser` again, the cycle repeats. When the robot finishes, the response is the task in state `completed` with the reply as its artifact.

**Setup:**

```ruby
RobotLab::A2A::Server.new(interactive: :a2a_tool, port: 7000)
  .add_robot(robot, name: "Planner", description: "Plans trips interactively")
  .run
```

**Robot interface required:**

- `robot.run(text)` — entry point.
- `robot.local_tools` — `Array` reader backed by the instance variable `@local_tools`, which the adapter replaces with a copy that has `AskUserTool` appended.

**Important:** Interactive resume requires a build of `simple_a2a` that includes `ResumeContext` support. See [Getting Started — Installation](getting-started.md#installation) for the path dependency pattern.

## `:io_bridge` mode

For robots that communicate via raw Ruby IO (`puts`/`gets`) rather than the `AskUser` tool. The server replaces `robot.input` and `robot.output` with an `IoBridge` instance at the start of the robot thread, and restores the previous streams on teardown.

`IoBridge` behaviour:

- **Writes** (`write`, `puts`, `print`) — accumulate into an internal buffer.
- **`gets`** — flushes the buffer as the `input_required` prompt (the buffered text, stripped, becomes the prompt; `"Input required:"` if nothing was written), then blocks on `answer_queue` until the A2A client resumes. The answer is returned from `gets` to the robot with a trailing newline.

The two-turn client pattern is identical to `:a2a_tool`.

```ruby
RobotLab::A2A::Server.new(interactive: :io_bridge, port: 7000)
  .add_robot(robot, name: "IO Robot", description: "Uses gets/puts for interaction")
  .run
```

**Robot interface required:**

- `robot.input=` / `robot.output=` — settable IO attributes.
- The robot must use `@input.gets` and `@output.puts` (or equivalent) rather than `$stdin`/`$stdout` directly.

**Important:** Interactive resume requires `simple_a2a` with `ResumeContext` support.

## Choosing a mode

| Mode | Robot interface required | Typical use case |
|---|---|---|
| `:none` | `robot.run(text) → result.reply` | Fully autonomous robots with no user prompts |
| `:a2a_tool` | `robot.run(text)` + `robot.local_tools` backed by `@local_tools` | Robots that use `RobotLab::AskUser` as a tool |
| `:io_bridge` | `robot.run(text)` + settable `robot.input=` / `robot.output=` | Robots that interact via raw stdin/stdout streams |

When in doubt, start with `:none`. Upgrade to `:a2a_tool` if your robot uses `AskUser`, or `:io_bridge` if it uses raw IO.

## Cancelling an in-progress task

While a robot is suspended waiting on `answer_queue` (i.e. between an `input_required` event and the client's resume), the A2A client may send `tasks/cancel` instead of resuming. `RobotAdapter#cancel` looks the task up in `Registry` by task ID, kills the robot thread with `Thread#kill`, and removes the entry from `Registry` before delegating to the default `AgentExecutor#cancel` behaviour. If no entry is found (e.g. the task already completed or was never interactive), `cancel` is a no-op aside from the default behaviour.
