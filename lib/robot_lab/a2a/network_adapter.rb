# frozen_string_literal: true

module RobotLab
  module A2A
    # Wraps a RobotLab::Network as an A2A AgentExecutor.
    #
    # Only :none interactive mode is supported — interactive flows require
    # per-robot queue injection across all network robots, planned for a future
    # release. Wrap individual robots with RobotAdapter for interactive flows.
    class NetworkAdapter < ::A2A::Server::AgentExecutor
      # :reek:ControlParameter -- interactive is only validated here; anything
      # but :none is rejected with a pointer to RobotAdapter.
      def initialize(network, interactive: :none)
        super()
        if interactive != :none
          raise ArgumentError,
                'NetworkAdapter only supports interactive: :none. ' \
                'For interactive network flows, wrap individual robots with RobotAdapter.'
        end

        @network = network
      end

      # :reek:FeatureEnvy -- AgentExecutor protocol method: it drives the task
      # lifecycle (start/complete/emit) on the request context handed to it.
      def call(context)
        context.task.start!
        context.emit_status

        input_text = context.message.text_content
        reply      = extract_reply(@network.run(message: input_text))

        artifact = ::A2A::Models::Artifact.new(
          parts: [::A2A::Models::Part.text(reply.to_s)],
          name: 'reply'
        )
        context.task.complete!(artifacts: [artifact])
        context.emit_status(final: true)
      end

      private

      # A real RobotLab::Network#run returns a SimpleFlow::Result whose #value
      # is the last robot's RobotResult; duck-typed networks may return an
      # object that answers #last_text_content directly.
      # :reek:UtilityFunction -- pure result unwrapping, kept on the adapter
      # so it can be tested in isolation.
      def extract_reply(result)
        result = result.value if !result.respond_to?(:last_text_content) && result.respond_to?(:value)
        result.respond_to?(:last_text_content) ? result.last_text_content : result
      end
    end
  end
end
