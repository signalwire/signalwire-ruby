# frozen_string_literal: true

module SignalWire
  module REST
    module Namespaces
      # 10DLC brand management.
      class RegistryBrands < BaseResource
        def list(**params) = @http.get(@base_path, params.empty? ? nil : params)
        def create(**kwargs) = @http.post(@base_path, kwargs)
        def get(brand_id) = @http.get(_path(brand_id))

        def list_campaigns(brand_id, **params)
          @http.get(_path(brand_id, 'campaigns'), params.empty? ? nil : params)
        end

        def create_campaign(brand_id, **kwargs)
          @http.post(_path(brand_id, 'campaigns'), kwargs)
        end
      end

      # 10DLC campaign management.
      class RegistryCampaigns < BaseResource
        def get(campaign_id) = @http.get(_path(campaign_id))
        def update(campaign_id, **kwargs) = @http.put(_path(campaign_id), kwargs)

        def list_numbers(campaign_id, **params)
          @http.get(_path(campaign_id, 'numbers'), params.empty? ? nil : params)
        end

        def list_orders(campaign_id, **params)
          @http.get(_path(campaign_id, 'orders'), params.empty? ? nil : params)
        end

        def create_order(campaign_id, **kwargs)
          @http.post(_path(campaign_id, 'orders'), kwargs)
        end
      end

      # 10DLC assignment order management.
      class RegistryOrders < BaseResource
        def get(order_id)
          @http.get(_path(order_id))
        end
      end

      # 10DLC number assignment management.
      class RegistryNumbers < BaseResource
        def delete(number_id)
          @http.delete(_path(number_id))
        end
      end

      # 10DLC Campaign Registry namespace.
      class RegistryNamespace
        attr_reader :brands, :campaigns, :orders, :numbers

        def initialize(http)
          base = '/api/relay/rest/registry/beta'
          @brands    = RegistryBrands.new(http, "#{base}/brands")
          @campaigns = RegistryCampaigns.new(http, "#{base}/campaigns")
          @orders    = RegistryOrders.new(http, "#{base}/orders")
          @numbers   = RegistryNumbers.new(http, "#{base}/numbers")
        end
      end
    end
  end
end
