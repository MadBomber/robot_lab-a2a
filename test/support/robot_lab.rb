# frozen_string_literal: true

# Minimal stub for robot_lab — keeps tests free of the gem's heavy transitive
# dependencies (ruby_llm, activesupport, etc.).
module RobotLab
  class Tool
    def self.description(text = nil); end
    def self.param(name, **opts); end
    def initialize(**opts); end
  end

  class AskUser < Tool; end
end
