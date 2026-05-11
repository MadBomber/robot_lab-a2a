# frozen_string_literal: true

module RobotLab
  module A2A
    # Drop-in replacement for RobotLab::AskUser when a robot runs under A2A.
    #
    # Instead of blocking a terminal, it pushes an input_required event through
    # the event_queue so the RobotAdapter can call task.require_input! and
    # emit_status(final: true), then blocks on answer_queue until the A2A client
    # resumes the task with another message.
    #
    # Inject before robot.run() via RobotAdapter — do not use directly.
    class AskUserTool < RobotLab::Tool
      description "Ask the user a clarifying question and wait for their response"
      param :question, type: "string", desc: "The question to present to the user"
      param :choices,  type: "array",  desc: "Optional list of choices to present", required: false
      param :default,  type: "string", desc: "Default value if user presses Enter",  required: false

      attr_writer :event_queue, :answer_queue

      def execute(question:, choices: nil, default: nil)
        raise "A2A queues not injected — use RobotLab::A2A::RobotAdapter" unless @event_queue

        prompt_text = format_prompt(question, choices, default)
        prompt      = ::A2A::Models::Message.agent(prompt_text)
        @event_queue.push({ type: :ask, prompt: prompt })

        answer = @answer_queue.pop
        answer = default if (answer.nil? || answer.strip.empty?) && default
        answer.to_s
      end

      private

      def format_prompt(question, choices, default)
        lines = [question]
        if choices.is_a?(Array) && choices.any?
          choices.each_with_index { |c, i| lines << "  #{i + 1}. #{c}" }
        end
        lines << "(Default: #{default})" if default
        lines.join("\n")
      end
    end
  end
end
