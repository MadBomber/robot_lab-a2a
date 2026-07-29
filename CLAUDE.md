# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Gem Does

`robot_lab-a2a` is an Agent2Agent (A2A) protocol adapter that exposes RobotLab robots and networks as A2A agents over HTTP+SSE. It bridges RobotLab's terminal-based `AskUser` tool to A2A's `input_required`/resume lifecycle, enabling multi-turn conversational flows without terminal dependency. It delegates HTTP serving to the `simple_a2a` gem.

## Commands

```bash
rake test              # Run full test suite (default rake task)
rake build             # Build the gem package
rake install           # Install gem locally

bin/setup              # Install dependencies
bin/console            # IRB session with gem loaded

# Run a single test file
ruby -Ilib -Itest test/robot_lab/test_a2a.rb

# Run a single test by name
ruby -Ilib -Itest test/robot_lab/test_a2a.rb -n test_registry_stores_and_retrieves
```

## Architecture

All source lives under `lib/robot_lab/a2a/`. The gem uses an adapter pattern — the two adapters both implement the `A2A::Server::AgentExecutor` interface with a single `call(context)` method.

### Key Abstractions

**Registry** (`registry.rb`) — Thread-safe singleton tracking active robot sessions across HTTP requests. Entries are `Data.define(:thread, :event_queue, :answer_queue)` stored by session ID. Required because A2A `tasks/send` resumes an in-flight robot thread.

**RobotAdapter** (`robot_adapter.rb`) — Wraps a `RobotLab::Robot` as an executor. Supports three interactive modes:
- `:none` — Synchronous, robot runs to completion with no input prompts.
- `:a2a_tool` — Injects `AskUserTool` into the robot's `@local_tools`, converting terminal blocking to Queue signaling. Restores original tools on teardown.
- `:io_bridge` — Replaces the robot's I/O streams with an `IoBridge` instance; works with robots that use `puts`/`gets` directly.

**AskUserTool** (`ask_user_tool.rb`) — Drop-in replacement for `RobotLab::AskUser`. On `call`, pushes `{type: :ask, prompt:}` to the event_queue then blocks on answer_queue until the A2A client sends a resume.

**IoBridge** (`io_bridge.rb`) — IO-compatible object. Buffers all writes; on `gets`, flushes the buffer as the prompt event and blocks on answer_queue. Enables interactive mode for robots that don't use the AskUser tool directly.

**NetworkAdapter** (`network_adapter.rb`) — Wraps a `RobotLab::Network`. Currently supports only `:none` mode; interactive mode per network node is not yet implemented.

**Server** (`server.rb`) — Fluent builder. `add_robot` / `add_network` register adapters keyed by DNS-safe path labels (underscores→hyphens, RFC 1123). `run(port:)` starts the HTTP server; `to_app` returns a Rack app for embedding in Rails/Puma.

### Thread Safety

Interactive modes run each robot on its own Ruby Thread. `Registry` uses a `Mutex`. `AskUserTool` and `IoBridge` use Ruby's `Queue` for producer/consumer coordination between the robot thread and the HTTP request handler.

### Extension Registration

The gem hooks into RobotLab's extension system at require time (`a2a.rb`) and registers itself as the `:a2a` extension.

## Tests

Tests live in `test/robot_lab/test_a2a.rb` using Minitest with autorun. The test helper is `test/test_helper.rb`. There is no `.rspec` or RuboCop config — no linter is configured.
