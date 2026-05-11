# frozen_string_literal: true

require "test_helper"

class RobotLab::A2A::AskUserToolTest < Minitest::Test
  def setup
    @event_queue  = Queue.new
    @answer_queue = Queue.new
    @tool = RobotLab::A2A::AskUserTool.new(robot: Object.new)
  end

  def test_execute_raises_without_injected_queues
    err = assert_raises(RuntimeError) { @tool.execute(question: "Hello?") }
    assert_match "A2A queues not injected", err.message
  end

  def test_execute_returns_answer
    @tool.event_queue  = @event_queue
    @tool.answer_queue = @answer_queue
    @answer_queue.push("blue")
    assert_equal "blue", @tool.execute(question: "Favourite colour?")
  end

  def test_execute_pushes_ask_event
    @tool.event_queue  = @event_queue
    @tool.answer_queue = @answer_queue
    @answer_queue.push("yes")
    @tool.execute(question: "Ready?")
    event = @event_queue.pop(true)
    assert_equal :ask, event[:type]
    refute_nil event[:prompt]
  end

  def test_execute_uses_default_when_answer_is_empty
    @tool.event_queue  = @event_queue
    @tool.answer_queue = @answer_queue
    @answer_queue.push("")
    result = @tool.execute(question: "Colour?", default: "red")
    assert_equal "red", result
  end

  def test_execute_uses_default_when_answer_is_blank
    @tool.event_queue  = @event_queue
    @tool.answer_queue = @answer_queue
    @answer_queue.push("   ")
    result = @tool.execute(question: "Size?", default: "medium")
    assert_equal "medium", result
  end

  def test_execute_with_choices_in_prompt
    @tool.event_queue  = @event_queue
    @tool.answer_queue = @answer_queue
    @answer_queue.push("2")
    @tool.execute(question: "Pick one:", choices: ["apple", "banana"])
    event = @event_queue.pop(true)
    assert_equal :ask, event[:type]
  end

  def test_execute_with_default_in_prompt
    @tool.event_queue  = @event_queue
    @tool.answer_queue = @answer_queue
    @answer_queue.push("")
    result = @tool.execute(question: "Enter value:", default: "42")
    assert_equal "42", result
  end
end
