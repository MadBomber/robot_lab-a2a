# frozen_string_literal: true

module RobotLab
  module A2A
    # IO-compatible wrapper for :io_bridge interactive mode.
    #
    # Inject as both robot.input and robot.output before robot.run().
    # Output written by AskUser (the prompt text) is buffered; when AskUser
    # calls gets(), the buffer becomes the input_required message and the call
    # blocks until the A2A client resumes the task with an answer.
    #
    # This lets existing robots that use RobotLab::AskUser work under A2A
    # without any modification — the terminal is replaced by the HTTP protocol.
    #
    # Only works with in-process storage: the robot thread must stay alive
    # between INPUT_REQUIRED and resume.
    class IoBridge
      def initialize(event_queue:, answer_queue:)
        @event_queue   = event_queue
        @answer_queue  = answer_queue
        @output_buffer = +""
        @buffer_mutex  = Mutex.new
      end

      # --- output side (robot.output) ---

      def print(*args)
        @buffer_mutex.synchronize { @output_buffer << args.map(&:to_s).join }
        nil
      end

      def puts(*args)
        @buffer_mutex.synchronize do
          if args.empty?
            @output_buffer << "\n"
          else
            args.each { |a| @output_buffer << a.to_s << "\n" }
          end
        end
        nil
      end

      def write(str)
        @buffer_mutex.synchronize { @output_buffer << str.to_s }
        str.to_s.length
      end

      def flush
        self
      end

      def sync=(*)
        # no-op — satisfy IO compatibility
      end

      # --- input side (robot.input) ---

      def gets
        prompt_text = @buffer_mutex.synchronize do
          text = @output_buffer.dup.strip
          @output_buffer.clear
          text
        end

        prompt = ::A2A::Models::Message.agent(
          prompt_text.empty? ? "Input required:" : prompt_text
        )
        @event_queue.push({ type: :ask, prompt: prompt })

        answer = @answer_queue.pop
        "#{answer}\n"
      end
    end
  end
end
