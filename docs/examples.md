# Examples

## Layout

```
examples/
  run                     # launcher script
  01_sync_robot/
    server.rb             # starts the A2A server
    client.rb             # sends a task and prints the result
  02_interactive_a2a_tool/
    server.rb
    client.rb
  03_robot_network/
    server.rb
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
