# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-a2a` is an Agent2Agent (A2A) protocol adapter that exposes RobotLab robots and networks as A2A agents over HTTP+SSE. It bridges RobotLab's terminal-based `AskUser` tool to A2A's `input_required`/resume lifecycle, enabling multi-turn conversational flows without terminal dependency. It delegates HTTP serving to the `simple_a2a` gem.

## Commands

```bash
rake test              # Run full test suite (default rake task)
asgard build           # Build the gem package
asgard install         # Install gem locally

bin/setup              # Install dependencies
bin/console            # IRB session with gem loaded

# Run a single test file
ruby -Ilib -Itest test/robot_lab/a2a_test.rb

# Run a single test by name
ruby -Ilib -Itest test/robot_lab/a2a_test.rb -n test_registry_stores_and_retrieves_entries
```

## Architecture

All source lives under `lib/robot_lab/a2a/`. The gem uses an adapter pattern — the two adapters both implement the `A2A::Server::AgentExecutor` interface via `call(context)`; `RobotAdapter` also overrides `cancel(context)`.

### Key Abstractions

**Registry** (`registry.rb`) — Thread-safe singleton tracking active robot sessions across HTTP requests. Entries are `Data.define(:thread, :event_queue, :answer_queue)` stored by A2A task ID. Required because A2A `tasks/send` resumes an in-flight robot thread.

**RobotAdapter** (`robot_adapter.rb`) — Wraps a `RobotLab::Robot` as an executor. Supports three interactive modes:
- `:none` — Synchronous, robot runs to completion with no input prompts.
- `:a2a_tool` — Injects `AskUserTool` into the robot's `@local_tools`, converting terminal blocking to Queue signaling. Any `RobotLab::AskUser` already in `@local_tools` is displaced for the duration of the run; teardown restores the robot's original tool list.
- `:io_bridge` — Replaces the robot's I/O streams (`robot.input=` / `robot.output=`) with an `IoBridge` instance; works with robots that use `puts`/`gets` directly. Teardown restores the previous streams.

In every mode the adapter calls `robot.run(text, tools: :inherit)` when the robot's `run` accepts a `tools:` keyword (core `Robot#run` defaults to `tools: :none`, which would offer the model no tools); duck-typed robots with a plain `run(text)` are called without it.

**AskUserTool** (`ask_user_tool.rb`) — Drop-in replacement for `RobotLab::AskUser`. On `execute`, pushes `{type: :ask, prompt:}` to the event_queue then blocks on answer_queue until the A2A client sends a resume.

**IoBridge** (`io_bridge.rb`) — IO-compatible object. Buffers all writes; on `gets`, flushes the buffer as the prompt event and blocks on answer_queue. Enables interactive mode for robots that don't use the AskUser tool directly.

**NetworkAdapter** (`network_adapter.rb`) — Wraps a `RobotLab::Network`. Reads the reply from `network.run(message:).value.last_text_content` (a real network returns a `SimpleFlow::Result`), or from `.last_text_content` directly for duck-typed networks. Currently supports only `:none` mode; interactive mode per network node is not yet implemented.

**Server** (`server.rb`) — Fluent builder. `add_robot` / `add_network` register adapters keyed by DNS-safe path labels (underscores and whitespace→hyphens, RFC 1123). `run` starts the HTTP server on the host/port given to `Server.new` (it takes no arguments); `to_app` returns a Rack app for embedding in Rails/Puma.

### Thread Safety

Interactive modes run each robot on its own Ruby Thread. `Registry` uses a `Mutex`. `AskUserTool` and `IoBridge` use Ruby's `Queue` for producer/consumer coordination between the robot thread and the HTTP request handler.

### Extension Registration

The gem hooks into RobotLab's extension system at require time (`a2a.rb`) and registers itself as the `:a2a` extension.

## Tests

Tests live in `test/robot_lab/*_test.rb` (`a2a_test.rb`, `adapters_test.rb`, `ask_user_tool_test.rb`, `io_bridge_test.rb`, `real_robot_lab_test.rb`, `registry_test.rb`, `server_test.rb`) using Minitest with autorun. The test helper is `test/test_helper.rb`; it loads a minimal `RobotLab` stub from `test/support/robot_lab.rb` instead of the real gem (`real_robot_lab_test.rb` therefore runs `test/real/real_robot_lab_suite.rb` in a child process against the real `robot_lab`, with the model call stubbed), and enforces SimpleCov minimums (95% line, 75% branch), so a single-file run reports its tests but exits non-zero on coverage. RuboCop is configured in `.rubocop.yml`; `asgard quality` runs all the quality gates.
