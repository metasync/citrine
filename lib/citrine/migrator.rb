# frozen-string-literal: true

module Citrine
  class Migrator < Actor
    MIGRATION_ACTIONS = %w[migrate rollback redo]

    def start_migration(command, opts = {})
      repository, cmd = parse_command(command)
      if validate_command(cmd)
        migration_repositories(repository).collect do |repo|
          future.send(:run_migration, repo, **cmd.merge!(opts))
        end.each { |f| f.value }
      end
      quit
    end

    protected

    def parse_command(command)
      cmd = {action: "migrate"}
      unless command.nil?
        repository, action, argument = command.split(":")
        cmd[:action] = action || "migrate"
        case cmd[:action]
        when "migrate"
          cmd[:version] = argument unless argument.nil?
        when "rollback", "redo"
          cmd[:step] = argument unless argument.nil?
        end
      end
      [repository, cmd]
    end

    def validate_command(cmd)
      if MIGRATION_ACTIONS.include?(cmd[:action])
        true
      else
        quit "Migration action must be: #{MIGRATION_ACTIONS.join(", ")}"
        false
      end
    end

    def migration_repositories(repository)
      if repository.nil?
        repositories
      else
        repositories.select do |r|
          repository == r.to_s or
            repository == actor(r).options[:database]
        end.tap do |repos|
          if repos.empty?
            quit "Error!! Migration repository #{repository} is NOT found"
          end
        end
      end
    end

    def repositories
      registered_actors.select do |name|
        actor(name).is_a?(Citrine::Repository::Base)
      end
    end

    def run_migration(repository, opts = {})
      actor(repository).run_migration(**opts)
    rescue => e
      error "Migration failed - #{actor(repository).options[:database]}: #{e.class.name} - #{e.message}"
    end
  end
end
