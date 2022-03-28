# frozen_string_literal: true

require "rom/constants"
require "rom/core"

module ROM
  # @api private
  module Components
    # @api public
    class Registry
      include Enumerable

      # @api private
      attr_reader :provider

      # @api private
      attr_reader :handlers

      DUPLICATE_ERRORS = {
        gateways: GatewayAlreadyDefinedError,
        datasets: DatasetAlreadyDefinedError,
        schemas: SchemaAlreadyDefinedError,
        relations: RelationAlreadyDefinedError,
        associations: AssociationAlreadyDefinedError,
        commands: CommandAlreadyDefinedError,
        mappers: MapperAlreadyDefinedError
      }.freeze

      # @api private
      def initialize(provider:, handlers: ROM.components)
        @provider = provider
        @handlers = handlers
      end

      # @api private
      def store
        @store ||= handlers.map { |handler| [handler.namespace, EMPTY_ARRAY.dup] }.to_h
      end

      # @api private
      def each
        store.each { |type, components|
          components.each { |component| yield(type, component) }
        }
      end

      # @api private
      def to_a
        flat_map { |_, components| components }
      end

      # @api private
      def call(key, &fallback)
        comp = detect { |_, component| component.key == key && !component.abstract? }&.last

        if comp
          comp.build
        elsif fallback
          fallback.()
        else
          raise KeyError, "+#{key}+ not found"
        end
      end

      # @api private
      def [](type)
        store[type]
      end

      # @api private
      def get(type, **opts)
        public_send(type, **opts).first
      end

      # @api private
      def add(type, item: nil, **options)
        component = item || build(type, **options)

        # if include?(type, component)
        #   other = get(type, key: component.key)

        #   raise(
        #     DUPLICATE_ERRORS[type],
        #     "#{provider}: +#{component.key}+ is already defined by #{other.provider}"
        #   )
        # end

        store[type] << component

        update(component.local_components)

        component
      end

      # @api private
      def replace(type, item: nil, **options)
        component = item || build(type, **options)
        delete(type, item) if include?(type, component)
        store[type] << component
        component
      end

      # @api private
      def delete(type, item)
        self[type].delete(item)
        self
      end

      # @api private
      def update(other, **options)
        other.each do |type, component|
          add(
            type,
            item: component.with(provider: provider, config: component.config.join(options, :right))
          )
        end
        self
      end

      # @api private
      def build(type, **options)
        handlers[type].build(**options, provider: provider)
      end

      # @api private
      def include?(type, component)
        !component.abstract? && keys(type).include?(component.key)
      end

      # @api private
      def key?(key)
        keys.include?(key)
      end

      # @api private
      def keys(type = nil)
        if type
          self[type].map(&:key)
        else
          to_a.map(&:key)
        end
      end

      CORE_COMPONENTS.each do |type|
        define_method(type) do |**opts|
          all = self[type]
          return all if opts.empty?

          all.select { |el| opts.all? { |key, value| el.public_send(key).eql?(value) } }
        end
      end
    end
  end
end
