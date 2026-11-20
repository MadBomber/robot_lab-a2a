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
        reply      = @network.run(message: input_text).last_text_content

        artifact = ::A2A::Models::Artifact.new(
          parts: [::A2A::Models::Part.text(reply.to_s)],
          name: 'reply'
        )
        context.task.complete!(artifacts: [artifact])
        context.emit_status(final: true)
      end
    end
  end
end
