# frozen_string_literal: true

require 'test_helper'
require 'open3'
require 'rbconfig'

module RobotLab
  module A2A
    # Runs test/real/real_robot_lab_suite.rb in a child process. This process
    # has the RobotLab stub loaded (test/support/robot_lab.rb), so real
    # RobotLab::Robot / RobotLab::Network objects can only be exercised
    # out-of-process.
    class RealRobotLabTest < Minitest::Test
      SUITE = File.expand_path('../real/real_robot_lab_suite.rb', __dir__)

      def test_adapters_work_with_real_robot_lab_objects
        output, status = Open3.capture2e(RbConfig.ruby, SUITE)

        assert_predicate status, :success?, "real robot_lab suite failed:\n#{output}"
      end
    end
  end
end
