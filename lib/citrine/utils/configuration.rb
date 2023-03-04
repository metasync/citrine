# frozen-string-literal: true

require "pathname"
require "yaml"
require "erb"

module Citrine
  module Utils
    class Configuration
      using CoreRefinements

      attr_reader :config_files

      def initialize(config_files)
        @config_files = Array(config_files)
        init_config_files
        on_init
        validate
        load
        set_default_values
        post_init
      end

      def [](key)
        Utils.deep_clone(@config[key])
      end

      def fetch(key)
        @config[key]
      end

      def has_key?(key)
        @config.has_key?(key)
      end

      def merge(other_config)
        config.deep_merge!(convert_to_hash(other_config))
      end

      def convert_to_hash(other_config)
        other_config.is_a?(Citrine::Utils::Configuration) ?
          other_config.value : other_config.symbolize_keys
      end

      def value(stringify: false)
        stringify ? config.stringify_keys : config
      end

      protected

      attr_reader :config

      def init_config_files
        config_files.map! { |config_file| Pathname.new(config_file) }
      end

      def on_init
      end

      def post_init
      end

      def set_default_values
      end

      def validate
        config_files.each do |config_file|
          unless config_file.file?
            abort "Error!! Config file NOT found: #{config_file}"
          end
        end
      end

      def load
        config_files.inject(@config = {}) do |config, config_file|
          config.deep_merge!(
            load!(config_file).symbolize_keys.tap do |c|
              include_config_files(c, work_dir: config_file.dirname)
            end
          )
        end
      end
      alias_method :reload, :load

      def load!(config_file)
        YAML.safe_load(ERB.new(File.read(config_file), trim_mode: "<>").result)
      end

      def loader_class
        Citrine::Utils::Configuration
      end

      def include_config_files(conf, work_dir:)
        if conf.is_a?(Hash)
          files = (conf.delete(:include) || []).map! do |f|
            Dir[work_dir.join(f)]
          end.flatten
          conf.replace(loader_class.new(files).value.deep_merge!(conf)) unless files.empty?
          conf.each_value { |v| include_config_files(v, work_dir: work_dir) }
        elsif conf.is_a?(Array)
          conf.each { |v| include_config_files(v, work_dir: work_dir) }
        end
      end
    end
  end
end
