module Signalwire::Blade
  class Netcast
    NONE = "none"
    ROUTE_ADD = "route.add"
    ROUTE_REMOVE = "route.remove"

    IDENTITY_ADD = "identity.add"
    IDENTITY_REMOVE = "identity.remove"

    PROTOCOL_ADD = "protocol.add"
    PROTOCOL_REMOVE = "protocol.remove"

    PROTOCOL_PROVIDER_ADD = "protocol.provider.add"
    PROTOCOL_PROVIDER_REMOVE = "protocol.provider.remove"

    PROTOCOL_PROVIDER_DATA_UPDATE = "protocol.provider.data.update"
    PROTOCOL_PROVIDER_RANK_UPDATE = "protocol.provider.rank.update"

    PROTOCOL_CHANNEL_ADD = "protocol.channel.add"
    PROTOCOL_CHANNEL_REMOVE = "protocol.channel.remove"

    PROTOCOL_METHOD_ADD = "protocol.method.add"
    PROTOCOL_METHOD_REMOVE = "protocol.method.remove"

    SUBSCRIPTION_ADD = "subscription.add"
    SUBSCRIPTION_REMOVE = "subscription.remove"

    AUTHORITY_ADD = "authority.add"
    AUTHORITY_REMOVE = "authority.remove"

    AUTHORIZATION_ADD = "authorization.add"
    # AUTHORIZATION_UPDATE = "authorization.update" # Not implemented. Will be used "authorization.add" instead
    AUTHORIZATION_REMOVE = "authorization.remove"

    ACCESS_ADD = "access.add"
    ACCESS_REMOVE = "access.remove"
  end
end
