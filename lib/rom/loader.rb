# frozen_string_literal: true

require "pathname"
require "zeitwerk"

require "rom/support/inflector"

require "rom/types"
require "rom/initializer"
require "rom/loader"

module ROM
  # AutoRegistration is used to load component files automatically from the provided directory path
  #
  # @api public
  class Loader
    extend Initializer

    NamespaceType = Types::Strict::Bool | Types.Instance(Module)

    PathnameType = Types.Constructor(Pathname, &Kernel.method(:Pathname))

    InflectorType = Types.Interface(:camelize)

    ComponentDirs = Types::Strict::Hash.constructor { |hash| hash.transform_values(&:to_s) }

    DEFAULT_MAPPING = {
      relations: "relations",
      mappers: "mappers",
      commands: "commands"
    }.freeze

    # @!attribute [r] directory
    #   @return [Pathname] The root path
    param :root_directory, type: PathnameType.optional

    # @!attribute [r] namespace
    #   @return [Boolean,String]
    #     The name of the top level namespace or true/false which
    #     enables/disables default top level namespace inferred from the dir name
    option :namespace, type: NamespaceType, default: -> { true }

    # @!attribute [r] component_dirs
    #   @return [Hash] component => dir-name map
    option :component_dirs, type: ComponentDirs, default: -> { DEFAULT_MAPPING }

    # @!attribute [r] inflector
    #   @return [Dry::Inflector] String inflector
    #   @api private
    option :inflector, type: InflectorType, default: -> { Inflector }

    # @!attribute [r] components
    #   @return [ROM::Components]
    #   @api private
    option :components

    # Load components
    #
    # @api private
    def call
      return if @loaded || root_directory.nil?

      setup and backend.eager_load
      @loaded = true
    end

    private

    # @api private
    def backend
      @backend ||= Zeitwerk::Loader.new
    end

    # @api private
    # rubocop:disable Metrics/AbcSize
    def setup
      backend.inflector = inflector

      case namespace
      when true
        backend.push_dir(root_directory.join("..").realpath)

        component_dirs.each_value do |dir|
          backend.collapse(root_directory.join(dir).join("**/*"))
        end
      when false
        backend.push_dir(root_directory)
      else
        backend.push_dir(root_directory, namespace: namespace)
      end

      excluded_dirs.each do |dir|
        backend.ignore(dir)
      end

      backend.on_load do |_, constant, path|
        if (type = path_to_component_type(path))
          begin
            components.add(type, constant: constant, config: constant.config.component)
          rescue StandardError => e
            raise "Failed to load #{constant} from #{path}: #{e.message}"
          end
        end
      end

      backend.setup
    end
    # rubocop:enable Metrics/AbcSize

    # @api private
    def path_to_component_type(path)
      return unless File.file?(path)

      component_dirs
        .detect { |_, dir|
          path.start_with?(root_directory.join(dir).to_s)
        }
        &.first
    end

    # @api private
    def excluded_dirs
      root_directory
        .children
        .select(&:directory?)
        .reject { |dir| component_dirs.values.include?(dir.basename.to_s) }
        .map { |name| root_directory.join(name) }
    end
  end
end
