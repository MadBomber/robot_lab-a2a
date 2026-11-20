# frozen_string_literal: true

# Minimal stub for robot_lab — keeps tests free of the gem's heavy transitive
# dependencies (ruby_llm, activesupport, etc.).
module RobotLab
  class Tool
    def self.description(text = nil); end
    # ruby_llm 2.0 tool DSL
    def self.parameter(name, **opts); end
    def initialize(**opts); end
  end

  class AskUser < Tool; end
end
