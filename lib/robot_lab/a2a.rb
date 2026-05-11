# frozen_string_literal: true

require "robot_lab"
require "simple_a2a"
require "rack"

require_relative "a2a/version"
require_relative "a2a/registry"
require_relative "a2a/ask_user_tool"
require_relative "a2a/io_bridge"
require_relative "a2a/robot_adapter"
require_relative "a2a/network_adapter"
require_relative "a2a/server"

module RobotLab
  @_extensions = {} unless instance_variable_defined?(:@_extensions)

  class << self
    def register_extension(name, mod)
      @_extensions[name.to_sym] = mod
    end unless method_defined?(:register_extension) || respond_to?(:register_extension)

    def extension_loaded?(name)
      @_extensions.key?(name.to_sym)
    end unless method_defined?(:extension_loaded?) || respond_to?(:extension_loaded?)

    def extension(name)
      @_extensions[name.to_sym]
    end unless method_defined?(:extension) || respond_to?(:extension)
  end
end

RobotLab.register_extension(:a2a, RobotLab::A2A)
