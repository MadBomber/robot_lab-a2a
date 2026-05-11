# frozen_string_literal: true

require_relative "lib/robot_lab/a2a/version"

Gem::Specification.new do |spec|
  spec.name     = "robot_lab-a2a"
  spec.version  = RobotLab::A2A::VERSION
  spec.authors  = ["Dewayne VanHoozer"]
  spec.email    = ["dvanhoozer@gmail.com"]

  spec.summary     = "Agent2Agent (A2A) protocol adapter for RobotLab"
  spec.description = "Exposes RobotLab robots and networks as A2A agents over HTTP+SSE. " \
                     "Implements the Agent2Agent Protocol v1.0 (Linux Foundation) via the " \
                     "simple_a2a gem. Supports sync and interactive execution modes, bridging " \
                     "RobotLab's AskUser tool to A2A's input_required/resume lifecycle for " \
                     "multi-turn flows without a terminal dependency."
  spec.homepage = "https://github.com/MadBomber/robot_lab-a2a"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = spec.homepage
  spec.metadata["changelog_uri"]         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ sig/])
    end
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "robot_lab"
  spec.add_dependency "simple_a2a", "~> 0.3"
  spec.add_dependency "rack"
end
