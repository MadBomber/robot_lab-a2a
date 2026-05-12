## [Unreleased]

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

### Fixed

- `simple_a2a` `tasks/send` now routes a request carrying an existing `task_id` to a `ResumeContext` instead of always creating a new task, enabling full two-turn interactive resume per the A2A protocol spec
- `examples/run` invokes server and client via `bundle exec` so local path gem overrides are correctly activated when running demos directly from the `examples/` directory

## [0.1.0] - 2026-05-11

- Initial release
