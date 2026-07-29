# Examples

## Layout

```
examples/
  run                     # launcher script
  common_config.rb        # shared $LOAD_PATH + require, loaded by every example
  01_sync_robot/
    server.rb             # starts the A2A server
    client.rb             # sends a task and prints the result
  02_interactive_a2a_tool/
    server.rb
    client.rb
  03_robot_network/
    server.rb
    client.rb
  04_io_bridge/
    server.rb
    client.rb
  05_multi_agent/
    server.rb
    client.rb
  06_rack_mount/
    server.rb
    config.ru             # standalone Rack/Rails mount reference (not used by run)
    client.rb
```

## How to run

From the repo root, pass the example directory name to `examples/run`:

```bash
bundle exec ruby examples/run 01_sync_robot
```

From inside `examples/` directly:

```bash
cd examples
./run 01_sync_robot
```

The launcher starts `server.rb` in the background, waits for it to bind, then runs `client.rb` in the foreground so you see the output. Press Ctrl-C to stop.

To run server and client separately (useful for inspecting raw SSE output):

```bash
# Terminal 1
bundle exec ruby examples/01_sync_robot/server.rb

# Terminal 2
bundle exec ruby examples/01_sync_robot/client.rb
```

## 01_sync_robot

**Demonstrates:** The simplest possible integration. A robot with no user prompts is registered in `:none` mode and invoked with a single text message.

**What it shows:**

- `Server.new.add_robot(...).run(port:)` pattern
- A single `tasks/send` POST
- Parsing the SSE stream to extract `task_complete` payload

**Expected output (client):**

```
Sending task...
[event: task_started]
[event: task_complete]
Reply: The answer is 42.
Done.
```

## 02_interactive_a2a_tool

**Demonstrates:** A robot that calls `RobotLab::AskUser` during execution. The gem injects `AskUserTool`, converts the blocking call to an A2A `input_required` event, and the client resumes with the answer.

**Two-turn flow:**

1. Client sends initial task → server starts robot thread → robot calls `AskUser("What is your name?")` → SSE delivers `input_required` event with prompt and task ID.
2. Client sends a second `tasks/send` with the task ID and the user's answer → `AskUserTool` unblocks → robot continues → SSE delivers `task_complete`.

**What it shows:**

- `interactive: :a2a_tool` server setup
- How to extract `task_id` and `input_required` prompt from the first SSE stream
- How to construct the resume request with `task_id`

**Expected output (client):**

```
Turn 1 — sending initial task...
[event: task_started]
[event: input_required] prompt: "What is your name?"
task_id: abc-123-def

Turn 2 — resuming with answer...
[event: task_started]
[event: task_complete]
Reply: Hello, Alice! Nice to meet you.
Done.
```

## 03_robot_network

**Demonstrates:** A `RobotLab::Network` (multi-stage pipeline) exposed as a single A2A agent via `NetworkAdapter` in `:none` mode.

**Pipeline stages:** The example network typically chains two or three robots — for example, a research robot that gathers context, followed by a synthesis robot that produces a final answer. Each stage's output feeds the next.

**What it shows:**

- `add_network` registration
- That the caller sees only one A2A endpoint regardless of how many internal stages the network has
- `network.run(message: text).last_text_content` as the final reply

**Expected output (client):**

```
Sending task to network...
[event: task_started]
[event: task_complete]
Reply: [synthesised answer from the final pipeline stage]
Done.
```

## 04_io_bridge

**Demonstrates:** `:io_bridge` interactive mode. `QuoteRobot` has no knowledge of A2A at all — it just calls `@output.puts` and `@input.gets` (falling back to `$stdout`/`$stdin` when not injected), so the same class also runs fine interactively in a terminal. The server injects an `IoBridge` as `robot.input`/`robot.output` before each run.

**Two-turn flow:**

1. Client sends a topic (`"stoicism"`) → `QuoteRobot` writes its question to the buffered output, then calls `gets` → `IoBridge` flushes the buffer as the `input_required` prompt and blocks.
2. Client resumes with the same `task_id` and an answer (`"Ada"`) → `IoBridge` unblocks `gets` → the robot completes and returns a quote addressed to that name.

**What it shows:**

- `interactive: :io_bridge` server setup
- A robot written against plain Ruby IO, with no A2A-specific code
- The same two-turn `task_id` resume pattern as `:a2a_tool`

**Note:** Turn 2 requires a `simple_a2a` build with `ResumeContext` support (>= 0.3.1). On older versions the client still demonstrates Turn 1's `input_required` suspension.

## 05_multi_agent

**Demonstrates:** Multiple independent A2A agents served from a single process via the fluent builder API with explicit `path:` overrides — `HeadlineRobot` at `/headline` and `TagRobot` at `/tags`.

**What it shows:**

- Chaining `add_robot` calls with explicit `path:` values on one `Server` instance
- Two separate `A2A.client` instances, one per agent path, each with its own agent card
- That co-located agents are indistinguishable from independently hosted ones at the protocol level

**Expected output (client):** both clients discover their agent card, send the same input text, and print each robot's distinct reply (a capitalised headline vs. a list of `#hashtag` keywords) alongside pass/fail assertions.

## 06_rack_mount

**Demonstrates:** `server.to_app`, which returns a `Rack::URLMap` instead of starting a dedicated server — for embedding A2A agents inside a larger Rack application (Rails, Sinatra, Puma, etc.) rather than running `server.run` standalone.

The demo composes the A2A agent (`EchoRobot`, mounted via `to_app`) with a plain `/health` JSON Rack endpoint on the same combined app, run via `A2A::Server::FalconRunner`. `config.ru` in this directory is a copy-paste reference for mounting the same `to_app` result under Rackup or a Rails `config/routes.rb` — it is not used by `examples/run`.

**What it shows:**

- `add_robot(...).to_app` returning a `Rack::URLMap`
- Composing that map with unrelated Rack routes
- That both A2A and non-A2A routes work correctly side by side on the composed app

**Expected output (client):** a passing health check against `/health` followed by a normal A2A `send_task` round trip against `/echo-robot`, each reported with a pass/fail assertion.
