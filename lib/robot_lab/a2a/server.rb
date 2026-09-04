# frozen_string_literal: true

module RobotLab
  module A2A
    # Thin builder that registers RobotLab robots and networks as A2A agents
    # and delegates to simple_a2a for HTTP serving.
    #
    # Each robot or network is mounted at its own URL path. The path defaults
    # to "/dns-label-of-name" and can be overridden with the path: keyword.
    #
    # @example Basic usage
    #   server = RobotLab::A2A::Server.new
    #   server.add_robot(my_robot)
    #   server.run(port: 9292)
    #
    # @example Interactive robot (AskUser bridged to A2A input_required)
    #   server = RobotLab::A2A::Server.new(interactive: :a2a_tool)
    #   server.add_robot(my_robot)
    #   server.run(port: 9292)
    #
    # @example Multiple agents
    #   server = RobotLab::A2A::Server.new
    #   server.add_robot(analyst, path: "/analyst")
    #   server.add_robot(writer,  path: "/writer")
    #   server.add_network(pipeline, name: "pipeline", path: "/pipeline")
    #   server.run(port: 9292)
    #
    # @example Rack/Rails mount
    #   map "/agents" do
    #     run RobotLab::A2A::Server.new.add_robot(my_robot).to_app
    #   end
    #
    # :reek:DataClump -- name/description/path is the agent-card identity trio;
    # add_robot and add_network resolve caller overrides, build_agent_card consumes.
    class Server
      DEFAULT_VERSION = '1.0'

      # :reek:ControlParameter -- nil storage means "default to in-process Memory".
      def initialize(host: 'localhost', port: 9292, storage: nil, interactive: :none)
        @host        = host
        @port        = port
        @storage     = storage || ::A2A::Storage::Memory.new
        @interactive = interactive
        @agents      = {}
      end

      # Register a robot as an A2A agent.
      #
      # @param robot [RobotLab::Robot]
      # @param name [String, nil] overrides robot.name
      # @param description [String, nil] overrides robot.description
      # @param path [String, nil] URL path prefix (defaults to "/dns-label")
      # @return [self] for chaining
      # :reek:ControlParameter -- nil name/description/path mean "derive from
      # the robot"; each `||` is a default, not a behavior switch.
      def add_robot(robot, name: nil, description: nil, path: nil)
        agent_name = (name || robot.name).to_s
        agent_desc = description || robot.description || agent_name
        agent_path = path || "/#{dns_label(agent_name)}"
        adapter    = RobotAdapter.new(robot, interactive: @interactive)
        card       = build_agent_card(agent_name, agent_desc, path: agent_path)

        @agents[agent_path] = { agent_card: card, executor: adapter, storage: @storage }
        self
      end

      # Register a network as a single A2A agent (non-interactive).
      #
      # @param network [RobotLab::Network]
      # @param name [String] required — used for agent card and default path
      # @param description [String, nil]
      # @param path [String, nil] URL path prefix (defaults to "/dns-label")
      # @return [self] for chaining
      # :reek:ControlParameter -- nil description/path mean "derive from name";
      # each `||` is a default, not a behavior switch.
      def add_network(network, name:, description: nil, path: nil)
        if @interactive != :none
          raise ArgumentError,
                'NetworkAdapter only supports interactive: :none. ' \
                'Wrap individual robots with RobotAdapter for interactive flows.'
        end

        agent_name = name.to_s
        agent_desc = description || agent_name
        agent_path = path || "/#{dns_label(agent_name)}"
        adapter    = NetworkAdapter.new(network, interactive: :none)
        card       = build_agent_card(agent_name, agent_desc, path: agent_path)

        @agents[agent_path] = { agent_card: card, executor: adapter, storage: @storage }
        self
      end

      # Start the Falcon HTTP server.
      def run
        ::A2A.multi_server(agents: @agents, host: @host, port: @port).run
      end

      # Return a Rack app for embedding in other servers (e.g. Rails, Puma).
      # :reek:FeatureEnvy -- maps each registered agent config into its
      # simple_a2a rack app; the config hashes are this class's own @agents values.
      def to_app
        url_map = @agents.transform_values do |cfg|
          ::A2A.server(
            agent_card: cfg[:agent_card],
            executor: cfg[:executor],
            storage: cfg[:storage]
          ).rack_app
        end
        Rack::URLMap.new(url_map)
      end

      private

      def build_agent_card(name, description, path:)
        ::A2A::Models::AgentCard.new(
          name: name,
          description: description,
          version: DEFAULT_VERSION,
          capabilities: ::A2A::Models::AgentCapabilities.new,
          skills: [::A2A::Models::AgentSkill.new(name: 'chat', description: 'General conversation')],
          interfaces: [
            ::A2A::Models::AgentInterface.new(
              type: 'A2A',
              url: "http://#{@host}:#{@port}#{path}",
              version: DEFAULT_VERSION
            )
          ]
        )
      end

      # Convert a Ruby-style name to RFC 1123 DNS label format.
      # Underscores become hyphens; characters outside [a-z0-9-] are dropped.
      def dns_label(name)
        name.to_s.downcase.gsub('_', '-').gsub(/[^a-z0-9-]/, '').gsub(/\A-+|-+\z/, '')
      end
    end
  end
end
