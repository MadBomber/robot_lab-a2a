# frozen_string_literal: true

# robot_lab-a2a/examples/common_config.rb
#
# Loaded by every example. Puts the gem's lib/ on the path so examples run
# from a checkout without a gem install.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'robot_lab/a2a'
