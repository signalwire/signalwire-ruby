module Signalwire::Blade
  class NodeStore
    include Logging::HasLogger
    attr_reader :routes, :protocols, :subscriptions, :authorities

    def initialize(session)
      @session = session
      @routes = Concurrent::Hash.new
      @protocols = Concurrent::Hash.new
      @subscriptions = Concurrent::Hash.new
      @authorities = Concurrent::Array.new
      @authorizations = Concurrent::Hash.new
      @accesses = Concurrent::Hash.new
    end

    def populate_from_connect(result)
      result[:routes].each { |r| add_route(r) } if result[:routes]
      result[:protocols].each { |pr| @protocols[pr[:name]] = pr } if result[:protocols]
      result[:subscriptions].each { |s| @subscriptions[s[:protocol]] = s } if result[:subscriptions]
      @authorities = result[:authorities] if result[:authorities]
      result[:authorizations].each { |a| @authorizations[a[:authentication]] = a } if result[:authorizations]
      result[:accesses].each { |a| @accesses[a[:authentication]] = a } if result[:accesses]

      # print_stats
    end

    def netcast_update(netcast)
      params = netcast[:params]
      case netcast[:command]
      when Netcast::ROUTE_ADD then add_route(params)
      when Netcast::ROUTE_REMOVE then remove_route(params)

      when Netcast::IDENTITY_ADD then add_identity(params)
      when Netcast::IDENTITY_REMOVE then remove_identity(params)

      # when Blade::Netcast::PROTOCOL_ADD then false # TODO:
      # when Blade::Netcast::PROTOCOL_REMOVE then false # TODO:

      when Netcast::PROTOCOL_PROVIDER_ADD then add_protocol_provider(params)
      when Netcast::PROTOCOL_PROVIDER_REMOVE then remove_protocol_provider(params)

      # when Blade::Netcast::PROTOCOL_PROVIDER_DATA_UPDATE then false # TODO:
      # when Blade::Netcast::PROTOCOL_PROVIDER_RANK_UPDATE then false # TODO:

      # when Blade::Netcast::PROTOCOL_CHANNEL_ADD then false # TODO:
      # when Blade::Netcast::PROTOCOL_CHANNEL_REMOVE then false # TODO:

      # when Blade::Netcast::PROTOCOL_METHOD_ADD then false # TODO:
      # when Blade::Netcast::PROTOCOL_METHOD_REMOVE then false # TODO:

      # when Blade::Netcast::SUBSCRIPTION_ADD then add_subscription(params)
      # when Blade::Netcast::SUBSCRIPTION_REMOVE then remove_subscription(params)

      when Netcast::AUTHORITY_ADD then add_authority(params[:nodeid])
      when Netcast::AUTHORITY_REMOVE then remove_authority(params[:nodeid])

      # when Blade::Netcast::AUTHORIZATION_ADD then false # TODO:
      # when Blade::Netcast::AUTHORIZATION_REMOVE then false # TODO:

      # when Blade::Netcast::ACCESS_ADD then false # TODO:
      # when Blade::Netcast::ACCESS_REMOVE then false # TODO:
      else
        logger.error "Unknown netcast command: #{params[:command]}"
      end

      print_stats
    end

    private

    def add_identity(params)
      node = lookup(@routes, params[:nodeid])
      node[:identities] << params[:identity] if node
      lookup_provider(params[:nodeid]) do |protocol, provider|
        provider[:identities] << params[:identity]
      end
    end

    def remove_identity(params)
      node = lookup(@routes, params[:nodeid])
      node[:identities].delete(params[:identity]) if node
      lookup_provider(params[:nodeid]) do |protocol, provider|
        provider[:identities].delete(params[:identity])
      end
    end

    def add_route(route)
      route[:identities] = [] unless route.has_key?(:identities)
      @routes[route[:nodeid]] = route
    end

    def remove_route(params)
      lookup_provider(params[:nodeid]) do |protocol, provider, index|
        protocol[:providers].delete_at(index)
      end
      remove_authority(params[:nodeid])
      @routes.delete(params[:nodeid])
    end

    def add_protocol_provider(params)
      new_provider = { nodeid: params[:nodeid], data: {}, identities: [], rank: params[:rank] }
      protocol = lookup(@protocols, params[:protocol])
      if protocol.nil?
        add_protocol(params.merge(name: params[:protocol], providers: [new_provider]))
      else
        protocol[:providers] << new_provider
      end
    end

    def remove_protocol_provider(params)
      lookup_provider(params[:nodeid]) do |protocol, provider, index|
        protocol[:providers].delete_at(index) if protocol[:name] == params[:protocol]
      end
    end

    def add_subscription(params)
      # @@ TODO
    end

    def remove_subscription(params)
      # @@ TODO
    end

    def add_protocol(params)
      valid_keys = %i[name default_method_execute_access default_channel_broadcast_access default_channel_subscribe_access providers channels methods]
      new_protocol = params.slice(*valid_keys)
      if new_protocol.has_key?(:name) && new_protocol.has_key?(:providers)
        # FIXME: do not override if protocol already exists ?!
        @protocols[new_protocol[:name]] = new_protocol
        return new_protocol
      end
    end

    def remove_protocol(protocol)
      @protocols.delete(protocol[:name])
    end

    def add_authority(nodeid)
      @authorities << nodeid if @authorities.index(nodeid).nil?
    end

    def remove_authority(nodeid)
      @authorities.delete(nodeid)
    end

    # Helper Methods

    def lookup_provider(nodeid)
      @protocols.each do |protocol_name, protocol|
        protocol[:providers].each_with_index do |provider, index|
          yield(protocol, provider, index) if provider[:nodeid] == nodeid
        end
        @protocols.delete(protocol_name) if protocol[:providers].empty?
      end
    end

    # def remove_subscription(protocol)
    #   TODO: need to check @subscriptions structure
    #   if @subscriptions.key?(protocol)
    #     subscription = @subscriptions[protocol]
    #     @subscriptions.delete(protocol)
    #     logger.debug "Removed subscription #{subscription}"
    #   end
    # end

    def lookup(container, key)
      container[key] if container.is_a?(Hash) && container.has_key?(key)
    end

    def print_stats
      stats = []
      stats << "\n\tRoutes #{@routes.inspect}"
      stats << "\tProtocols #{@protocols.inspect}"
      stats << "\tSubscriptions #{@subscriptions.inspect}"
      stats << "\tAuthorities #{@authorities.inspect}"
      stats << "\tAuthorizations #{@authorizations.inspect}"
      stats << "\tAccesses #{@accesses.inspect}"
      logger.info stats.join("\n")
    end
  end
end
