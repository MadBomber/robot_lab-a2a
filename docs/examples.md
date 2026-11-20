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

The launcher starts `server.rb` in the background, waits for it to accept connections on port 9292, runs `client.rb` in the foreground so you see the output, then stops the server when the client exits.

To run server and client separately (useful for sending your own requests to the server):

```bash
# Terminal 1
bundle exec ruby examples/01_sync_robot/server.rb

# Terminal 2
bundle exec ruby examples/01_sync_robot/client.rb
```

## 01_sync_robot

**Demonstrates:** The simplest possible integration. A robot with no user prompts is registered in `:none` mode and invoked with a single text message.

**What it shows:**

- `Server.new(host:, port:)` + `add_robot(...)` + `run` pattern
- `A2A.client(url:)` discovering the agent card, then `send_task` (a `tasks/send` call) for each of three messages
- Reading the reply from the completed task's first artifact, then `list_tasks` and `get_task`

**Expected output (client):**

```
=== Agent Card ===
Name:        echo_robot
Description: Transforms every message: upcases it and reports character count
Skills:      chat

=== Sending Tasks ===
[completed]
  sent: "hello from robot_lab-a2a"
  got:  "HELLO FROM ROBOT_LAB-A2A  [24 chars, processed by EchoRobot]"

...two more tasks...

=== Task List ===
  <task-id>  state=completed
  <task-id>  state=completed
  <task-id>  state=completed
  Total: 3

=== Retrieve Task ===
id:    <task-id>
state: completed
reply: "HELLO FROM ROBOT_LAB-A2A  [24 chars, processed by EchoRobot]"

=== Verification ===
All tasks completed. PASS
```

## 02_interactive_a2a_tool

**Demonstrates:** A robot (`PersonalGreeterRobot`, a plain Ruby object) that calls the injected `AskUserTool` during execution. The gem injects `AskUserTool` into the robot's `local_tools`, converts the blocking call to an A2A `input_required` task, and the client resumes with the answer.

**Two-turn flow:**

1. Client sends initial task → server starts robot thread → robot calls `AskUserTool#execute(question: "What is your name?", choices: [...], default: "Friend")` → `send_task` returns the task in state `input_required`, with the formatted prompt as its status message.
2. Client calls `send_task` again with `task_id:` set to that task's ID and the user's answer → `AskUserTool` unblocks → robot continues → the same task comes back in state `completed`.

**What it shows:**

- `interactive: :a2a_tool` server setup
- How to read the task ID (`task.id`) and the prompt (`task.status.message`) from the first response
- How to construct the resume request with `task_id:`

**Expected output (client):**

```
=== Agent Card ===
Name:        personal_greeter
Description: Asks your name before composing a personalised greeting

=== Turn 1: Initial request ===
  Sending topic: 'the A2A protocol'

  Task ID: <task-id>
  State:   input_required
  Question: What is your name?
  1. Alice
  2. Bob
  3. Charlie
(Default: Friend)

=== Turn 2: Answer ===
  Answering: 'Alice'

  Task ID: <task-id>
  State:   completed
  Reply:   Hello, Alice! You wanted to know about: the A2A protocol

=== Verification ===
Turn 1 returned input_required   : PASS
Prompt contains numbered choices : PASS
Prompt shows default value       : PASS
Turn 2 completed after answer    : PASS
Reply mentions the caller name   : PASS

All assertions passed.
```

(Divider lines between sections are omitted here.)

## 03_robot_network

**Demonstrates:** A network-style pipeline (`EditorialPipeline`, a plain Ruby object implementing the `run(message:)` → `#last_text_content` interface that `NetworkAdapter` accepts alongside real `RobotLab::Network` objects) exposed as a single A2A agent via `NetworkAdapter` in `:none` mode.

**Pipeline stages:** The example chains three robots — `AnalyserRobot` (prefixes a word count), `FormatterRobot` (capitalises each word), and `SummaryRobot` (prefixes `SUMMARY →`). Each stage's output feeds the next.

**What it shows:**

- `add_network` registration
- That the caller sees only one A2A endpoint regardless of how many internal stages the network has
- The network's last text content (`network.run(message: text)`) as the final reply

**Expected output (client):**

```
=== Agent Card ===
Name:        editorial_pipeline
Description: Three-stage text pipeline: analyse → format → summarise
Skills:      chat

=== Pipeline Results ===
Input:  "the quick brown fox jumps over the lazy dog"
Output: "SUMMARY → [Analysed: 9 Words] The Quick Brown Fox Jumps Over The Lazy Dog"
State:  completed

...two more documents...

=== Verification ===
completed  : PASS
analysed   : PASS
formatted  : PASS
summarised : PASS

...repeated for each document...

All pipeline checks passed.
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
