# frozen-string-literal: true

require "optparse"
require "pathname"

module Citrine
  def self.run_cli(mod, &blk)
    create_cli(mod, &blk).run
  end

  def self.create_cli(mod, &blk)
    cli_class(mod).new(&blk)
  end

  def self.cli_class(mod)
    if mod.const_defined?(:CLI)
      mod.const_get(:CLI)
    else
      mod.const_set(:CLI, Class.new(Citrine::CLI))
    end
  end

  class CLI
    include Utils::BaseObject
    include Utils::Namespace

    class << self
      def inherited(subclass)
        super
        # Ensure operations from the base class
        # got inherited to its subclasses
        operations.each_pair do |name, description|
          subclass.operation(name, description)
        end
      end

      def operations = @operations ||= {}

      def operation(name, description)
        operations[name] = description
        operation_method = "run_#{name}"
        unless method_defined?(operation_method)
          define_method(operation_method) do
            launch_manager
            wait_for_signal
          rescue Interrupt
            get_manager.supervisor.terminate
          end
        end
      end
    end

    operation :setup, "Run system database migration"
    operation :migration, "Run application databse migration"
    operation :service, "Start application service"
    operation :jobs, "Start application jobs"

    def default_signals
      %w[INT TERM USR1 USR2 TTIN TTOU]
    end

    def run
      parse_options
      load_source_files
      run_operation
    end

    def operations
      self.class.operations.keys - (options[:exclude_operations] || [])
    end

    def parser
      @parser ||= create_parser
    end

    protected

    def on_init
      @options[:init_config_files] ||= []
      @options[:init_service_config_files] ||= []
      @options[:init_jobs_config_files] ||= []
      @options[:config_files] = []
      @options[:source_files] = []
      @options[:exclude_operations] ||= [:setup]
    end

    def post_init
      setup_signal_handler
    end

    def setup_signal_handler
      @self_read, @self_write = IO.pipe
      default_signals.each do |sig|
        trap sig do
          @self_write.puts(sig)
        end
      rescue ArgumentError
        puts "Signal #{sig} not supported"
      end
    end

    def create_parser
      OptionParser.new do |parser|
        add_parser_bannder(parser)
        add_parser_options(parser)
        parser.separator("")
        add_parser_operations(parser)
      end
    end

    def add_parser_bannder(parser)
      parser.banner = "Usage: #{$0} [options] [#{operations.join("|")}]"
    end

    def add_parser_options(parser)
      parser.on("-c", "--config CONFIG_FILE",
        "Configuration file(s) in YAML (default: config.yml)") do |config_file|
        options[:config_files] << config_file
      end
      parser.on("-r", "--source SOURCE_FILE",
        "Source code file(s) in YAML") do |source_file|
        options[:source_files] << source_file
      end
      parser.on("-v", "--version", "Show version") do
        puts "Version: #{get_constant("VERSION")}"
        exit
      end
      parser.on("-h", "--help", "Show this message") do
        puts parser
        exit
      end
    end

    def add_parser_operations(parser)
      parser.separator("Commands:")
      operations.each do |name|
        parser.separator("    #{name}\t\t#{self.class.operations[name]}")
      end
    end

    def parse_options
      parser.parse!
      parse_operation
      set_config_files
    end

    def set_config_files
      if options[:config_files].empty?
        options[:config_files] << default_config_file
      end

      include_init_config_files
      case options[:operation]
      when :service
        include_init_config_files(:init_service_config_files)
      when :jobs
        include_init_config_files(:init_jobs_config_files)
      end

      options[:config_files].each do |config_file|
        unless File.file?(config_file)
          abort "Error!! Config file NOT found: #{config_file}"
        end
      end
    end

    def default_config_file
      config_file = default_config_file_by_operation(options[:operation])
      unless config_file.file?
        if options[:operation] == :service
          config_file = default_base_config_file
        else
          file = default_config_file_by_operation("service")
          config_file = file.file? ? file : default_base_config_file
        end
      end
      config_file
    end

    def default_config_file_by_operation(operation)
      Pathname.pwd.join("config", operation.to_s, "config.yml")
    end

    def default_base_config_file
      Pathname.pwd.join("config", "config.yml")
    end

    def include_init_config_files(files = :init_config_files)
      unless options[files].empty?
        options[:config_files] = options[files].concat(options[:config_files])
      end
    end

    def load_source_files
      options[:source_files].each do |source_file|
        path = Pathname.new(source_file)
        path = Pathname.pwd.join(path) unless path.absolute?
        if path.file?
          require path
        else
          abort "Error!! Source file NOT found: #{source_file}"
        end
      end
    end

    def parse_operation
      options[:operation] = (ARGV[0] || options[:default_operation] || "service").to_sym
      unless operations.include?(options[:operation])
        abort "Error!! Operation must be: #{operations.join(", ")}"
      end
      parse_operation_options = "parse_operation_#{options[:operation]}"
      send(parse_operation_options) if respond_to?(parse_operation_options, true)
    end

    def parse_operation_setup
      options[:migration_command] = ARGV[1]
    end

    def parse_operation_migration
      options[:migration_command] = ARGV[1]
    end

    def parse_operation_jobs
      options[:job_filter] = ARGV[1]
    end

    def run_operation
      send("run_#{options[:operation]}")
    end

    def launch_manager
      create_manager.launch(**options)
    end

    def create_manager
      get_or_set_constant("Manager", namespace: namespace_module,
        base: Citrine::Manager)
    end

    def get_manager
      get_constant("Manager", namespace: namespace_module)
    end

    def wait_for_signal
      while (readable_io = IO.select([@self_read]))
        signal = readable_io.first[0].gets.strip
        handle_signal(signal)
      end
    end

    def handle_signal(sig)
      send("handle_signal_#{sig.downcase}")
    end

    def handle_signal_int = raise(Interrupt)
    alias_method :handle_signal_term, :handle_signal_int

    def handle_signal_usr1
    end

    def handle_signal_usr2
    end

    def handle_signal_ttin
    end

    def handle_signal_ttou
    end
  end
end
