# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'

  add_group 'A2A', 'lib/robot_lab/a2a'

  enable_coverage :branch
end

$LOAD_PATH.unshift File.expand_path("support", __dir__)
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "robot_lab/a2a"

require 'minitest/autorun'

class Minitest::Test
  def wait_until(timeout: 1, interval: 0.005)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return if yield
      raise "wait_until timed out after #{timeout}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      sleep interval
    end
  end
end
