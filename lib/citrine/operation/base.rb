# frozen-string-literal: true

module Citrine
  class Operation
    include Utils::Common

    class Success < Result
      code Result::DEFAULT_SUCCESS_CODE
      message Result::DEFAULT_SUCCESS_MESSAGE
    end

    class Failure < Result
      code { |ctx| ctx[:error].class.name }
      message do |ctx|
        "Request failed due to unexpected error: #{ctx[:error].message}\n#{ctx[:error].full_message}"
      end
    end

    class InvalidContract < Result
      code { |ctx| ctx[:error].class.name.demodulize }
      message { |ctx| ctx[:error].message }
    end

    class FailedTask < Error
      def initialize(task)
        super("Failed to run #{task.type} task: #{task.name}")
      end
    end

    class << self
      def inherited(subclass)
        super
        # Ensure tasks from the base class
        # got inherited to its subclasses
        [step_tasks, fail_tasks].each do |tasks|
          unless tasks.empty?
            tasks.each do |task|
              subclass.send(task.type, task.name, **task.options)
            end
          end
        end

        def define_result(&blk)
          result_class = const_set(:Result, Class.new(Citrine::Operation::Result, &blk))
          const_set(:Success,
            Class.new(result_class) do
              code Citrine::Operation::Result::DEFAULT_SUCCESS_CODE
              message Citrine::Operation::Result::DEFAULT_SUCCESS_CODE
            end)
          const_set(:Failure,
            Class.new(result_class) do
              code { |ctx| self.class.name.demodulize + "Failure" }
              message do |ctx|
                "Failed to #{ctx[:failed_task].name.to_s.tr("_", " ")}: " \
                "#{ctx[:error].message} (#{ctx[:error].class.name})"
              end
            end)
        end
      end

      def contract(&blk)
        define_singleton_method(:contract) do
          @contract ||= Schema.new(&blk)
        end

        define_method(:contract) { self.class.contract }

        define_method(:validate_contract) do |context|
          context[:contract] = contract.parse(context[:params])
          if contract.error?
            context[:error] = contract.error
            context[:result] = InvalidContract.new(context)
            false
          else
            true
          end
        end
        step :validate_contract
      end

      def step_tasks = @step_tasks ||= []

      def fail_tasks = @fail_tasks ||= []

      def step(task, **opts)
        step_tasks << Task.new(:step, task, opts)
      end

      def pass(task, **opts)
        step_tasks << Task.new(:pass, task, opts)
      end

      def failure(task, **opts)
        fail_tasks << Task.new(:failure, task, opts)
      end
    end

    def call(**params)
      context = create_context(**params).tap do |context|
        run_step_tasks(context)
        run_fail_tasks(context) if context.failed?
        set_default_result(context)
      end
      context[:result]
    end

    protected

    def create_context(**params)
      Context.new(params: params)
    end

    def run_step_tasks(context)
      self.class.step_tasks.each do |task|
        run_step_task(task, context)
        break if context.failed?
      end
    end

    def run_step_task(task, context)
      send(task.name, context) or task.pass? or raise FailedTask.new(task)
    rescue => e
      context[:failed_task] = task
      context[:error] = e
      false
    end

    def run_fail_tasks(context)
      self.class.fail_tasks.each do |task|
        run_fail_task(task, context)
      end
    end

    def run_fail_task(task, context)
      send(task.name, context)
    end

    def set_default_result(context)
      context[:result] ||= result_class(context).new(context)
    end

    def result_class(context)
      self.class.const_get(context.failed? ? "Failure" : "Success")
    end

    def fail_operation_by_task(context)
      "fail_#{context[:failed_task].name}".tap do |task|
        send(task, context) if respond_to?(task, true)
      end
      context[:result] = self.class.const_get(:Failure).new(context)
    end
  end
end
