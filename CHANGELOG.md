## [Unreleased]

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
