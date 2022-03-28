# frozen_string_literal: true

require "rom/open_struct"
require_relative "core"

module ROM
  module Components
    # @api public
    class Gateway < Core
      # @api public
      def build
        gateway = adapter.is_a?(ROM::Gateway) ? adapter : setup

        # TODO: once Gateway is unified with the rest of component types, this
        #       won't be needed as it'll happen automatically when inheriting
        #       config settings
        gateway_config.plugins.concat(gateway.class.config.component.plugins)

        gateway.instance_variable_set("@config", gateway_config)
        gateway.use_logger(config.logger) if config.logger

        gateway
      end

      # @api private
      def adapter
        config.adapter
      end

      private

      # @api private
      def setup
        if config.args.empty?
          ROM::Gateway.setup(adapter, **config)
        else
          ROM::Gateway.setup(adapter, *config.args)
        end
      end

      # @api private
      def gateway_config
        hash = config.to_h
        keys = hash.keys - %i[type namespace opts]

        ROM::OpenStruct.new(**keys.zip(hash.values_at(*keys)).to_h, **config.opts)
      end
    end
  end
end
