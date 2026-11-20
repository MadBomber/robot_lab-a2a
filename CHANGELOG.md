## [Unreleased]

### Fixed

- **`NetworkAdapter` now works with a real `RobotLab::Network`.** `Network#run` returns a `SimpleFlow::Result`, so the reply is read from `result.value.last_text_content`; duck-typed networks whose result answers `last_text_content` directly still work. Previously every real network task failed with `NoMethodError`.
- **Robot tools are offered to the model.** `RobotAdapter` calls `robot.run(text, tools: :inherit)` when the robot's `run` accepts a `tools:` keyword. Core `Robot#run` defaults to `tools: :none`, so the injected `AskUserTool` (`:a2a_tool`) and core `AskUser` (`:io_bridge`) were never sent to the model. Applies in `:none` mode too.
- **Interactive teardown restores the robot.** `:a2a_tool` puts back the robot's original `local_tools` (a displaced `RobotLab::AskUser` used to be lost after the first run); `:io_bridge` restores the previous `input`/`output` instead of setting them to `nil`.
- **Failed tasks carry an A2A `Message`.** `task.fail!` was given a bare `String`, which serialised into a `status.message` that clients could not parse as a message.
- **Path labels hyphenate whitespace.** `"My Robot"` now maps to `/my-robot` (was `/myrobot`) and `"GPT-4 Agent!"` to `/gpt-4-agent`, as documented. Agents registered under a name containing spaces and no explicit `path:` move to the hyphenated path.
- `mkdocs.yml` no longer references the non-existent `assets/css/custom.css`.
- Example comments: the real-network snippet in `03_robot_network` uses `task` (not `step`), and the real-LLM snippet in `02_interactive_a2a_tool` attaches `RobotLab::AskUser` via `local_tools:`.

### Added

- `test/real/real_robot_lab_suite.rb`, run in a child process by `test/robot_lab/real_robot_lab_test.rb`, exercises the adapters against the real `robot_lab` gem (the main suite uses a stub) with the model call stubbed out.

## [0.6.1] - 2026-11-19

### Changed

- **Minimum Ruby raised to 4.0.9.** `required_ruby_version` is now `>= 4.0.9` (was `>= 3.2.0`), and a `.ruby-version` file pins development to 4.0.9.
- **Requires `robot_lab ~> 0.6`** (was `~> 0.3.0`). Verified against robot_lab 0.6.1 and ruby_llm 2.2.3; no code changes were needed.

## [0.2.8] - 2026-09-09

Released in lockstep with `robot_lab` core v0.2.8: this gem now resolves the released core gem from RubyGems instead of the local sibling checkout (local-path development remains available via `BUNDLE_GEMFILE=Gemfile.local`). Also in this release: reek warnings triaged to zero, and the gem lifecycle tasks (build/install/release) moved from the Rakefile to the asgard task runner.

### Added
- `.loki` Asgard task file: `test`, `rubocop`, `rubocop_fix`, `flog`, `flay`, `quality`, `build`, `install`, `release`, and `console` tasks via the Asgard task runner
- `flay_check` Rake task: structural code duplication gate (mass threshold 50); integrated into the `quality` Rake task
- `flay` and `minitest-reporters` gems added to development dependencies
- `test_output.txt`, `flay_output.txt`, `flog_output.txt`, and `rubocop_output.txt` added to `.gitignore`

### Changed
- `test/test_helper.rb`: test output redirected to `test_output.txt` via `$stdout` reassignment; `TerminalSummaryReporter` prints a single PASS/FAIL summary line to the terminal
- `Rakefile`: `rubocop` and `rubocop_fix` tasks removed (now owned by Asgard); `flay_check` integrated into the `quality` gate

## [0.2.1] - 2026-05-19

### Added

- Demo examples infrastructure: `examples/run` lifecycle script, shared `examples/common_config.rb`, and three complete demos:
  - `01_sync_robot` — synchronous EchoRobot in `:none` mode with task list and retrieve
  - `02_interactive_a2a_tool` — two-turn interactive flow using `AskUserTool` injection and A2A resume
  - `03_robot_network` — three-stage `EditorialPipeline` (AnalyserRobot → FormatterRobot → SummaryRobot) via `NetworkAdapter`
- Comprehensive test suite covering `Registry`, `IoBridge`, `AskUserTool`, `Server`, `RobotAdapter` (all three modes), and `NetworkAdapter`
- SimpleCov branch coverage with 95% line and 75% branch thresholds enforced by the `quality` Rake task
- `.rubocop.yml` with project-appropriate metric thresholds; `examples/` excluded from linting

### Changed

- Interactive mode `:acp_tool` renamed to `:a2a_tool` across all source, tests, and documentation
- Version synchronized with robot_lab core 0.2.1

### Fixed

- `simple_a2a` `tasks/send` now routes a request carrying an existing `task_id` to a `ResumeContext` instead of always creating a new task, enabling full two-turn interactive resume per the A2A protocol spec
- `examples/run` invokes server and client via `bundle exec` so local path gem overrides are correctly activated when running demos directly from the `examples/` directory

## [0.1.0] - 2026-05-11

- Initial release
