module GoodJob
  #
  # +GoodJob::Configuration+ provides normalized configuration information to
  # the rest of GoodJob. It combines environment information with explicitly
  # set options to get the final values for each option.
  #
  class Configuration
    # Default number of threads to use per {Scheduler}
    DEFAULT_MAX_THREADS = 5
    # Default number of seconds between polls for jobs
    DEFAULT_POLL_INTERVAL = 10
    # Default number of threads to use per {Scheduler}
    DEFAULT_MAX_CACHE = 10000
    # Default number of seconds to preserve jobs for {CLI#cleanup_preserved_jobs}
    DEFAULT_CLEANUP_PRESERVED_JOBS_BEFORE_SECONDS_AGO = 24 * 60 * 60
    # Default to always wait for jobs to finish for {#shutdown}
    DEFAULT_SHUTDOWN_TIMEOUT = -1

    # The options that were explicitly set when initializing +Configuration+.
    # @return [Hash]
    attr_reader :options

    # The environment from which to read GoodJob's environment variables. By
    # default, this is the current process's environment, but it can be set
    # to something else in {#initialize}.
    # @return [Hash]
    attr_reader :env

    # @param options [Hash] Any explicitly specified configuration options to
    #   use. Keys are symbols that match the various methods on this class.
    # @param env [Hash] A +Hash+ from which to read environment variables that
    #   might specify additional configuration values.
    def initialize(options, env: ENV)
      @options = options
      @env = env
    end

    # Specifies how and where jobs should be executed. See {Adapter#initialize}
    # for more details on possible values.
    #
    # When running inside a Rails app, you may want to use
    # {#rails_execution_mode}, which takes the current Rails environment into
    # account when determining the final value.
    #
    # @param default [Symbol]
    #   Value to use if none was specified in the configuration.
    # @return [Symbol]
    def execution_mode(default: :external)
      if defined?(GOOD_JOB_WITHIN_CLI) && GOOD_JOB_WITHIN_CLI
        :external
      elsif options[:execution_mode]
        options[:execution_mode]
      elsif rails_config[:execution_mode]
        rails_config[:execution_mode]
      elsif env['GOOD_JOB_EXECUTION_MODE'].present?
        env['GOOD_JOB_EXECUTION_MODE'].to_sym
      else
        default
      end
    end

    # Like {#execution_mode}, but takes the current Rails environment into
    # account (e.g. in the +test+ environment, it falls back to +:inline+).
    # @return [Symbol]
    def rails_execution_mode
      if execution_mode(default: nil)
        execution_mode
      elsif Rails.env.development? || Rails.env.test?
        :inline
      else
        :external
      end
    end

    # Indicates the number of threads to use per {Scheduler}. Note that
    # {#queue_string} may provide more specific thread counts to use with
    # individual schedulers.
    # @return [Integer]
    def max_threads
      (
        options[:max_threads] ||
          rails_config[:max_threads] ||
          env['GOOD_JOB_MAX_THREADS'] ||
          env['RAILS_MAX_THREADS'] ||
          DEFAULT_MAX_THREADS
      ).to_i
    end

    # Describes which queues to execute jobs from and how those queues should
    # be grouped into {Scheduler} instances. See
    # {file:README.md#optimize-queues-threads-and-processes} for more details
    # on the format of this string.
    # @return [String]
    def queue_string
      options[:queues] ||
        rails_config[:queues] ||
        env['GOOD_JOB_QUEUES'] ||
        '*'
    end

    # The number of seconds between polls for jobs. GoodJob will execute jobs
    # on queues continuously until a queue is empty, at which point it will
    # poll (using this interval) for new queued jobs to execute.
    # @return [Integer]
    def poll_interval
      (
        options[:poll_interval] ||
          rails_config[:poll_interval] ||
          env['GOOD_JOB_POLL_INTERVAL'] ||
          DEFAULT_POLL_INTERVAL
      ).to_i
    end

    # The maximum number of future-scheduled jobs to store in memory.
    # Storing future-scheduled jobs in memory reduces execution latency
    # at the cost of increased memory usage. 10,000 stored jobs = ~20MB.
    # @return [Integer]
    def max_cache
      (
        options[:max_cache] ||
          rails_config[:max_cache] ||
          env['GOOD_JOB_MAX_CACHE'] ||
          DEFAULT_MAX_CACHE
      ).to_i
    end

    # The number of seconds to wait for jobs to finish when shutting down
    # before stopping the thread. +-1+ is forever.
    # @return [Numeric]
    def shutdown_timeout
      (
        options[:shutdown_timeout] ||
          rails_config[:shutdown_timeout] ||
          env['GOOD_JOB_SHUTDOWN_TIMEOUT'] ||
          DEFAULT_SHUTDOWN_TIMEOUT
      ).to_f
    end

    # Number of seconds to preserve jobs when using the +good_job cleanup_preserved_jobs+ CLI command.
    # This configuration is only used when {GoodJob.preserve_job_records} is +true+.
    # @return [Integer]
    def cleanup_preserved_jobs_before_seconds_ago
      (
        options[:before_seconds_ago] ||
          rails_config[:cleanup_preserved_jobs_before_seconds_ago] ||
          env['GOOD_JOB_CLEANUP_PRESERVED_JOBS_BEFORE_SECONDS_AGO'] ||
          DEFAULT_CLEANUP_PRESERVED_JOBS_BEFORE_SECONDS_AGO
      ).to_i
    end

    # Tests whether to daemonize the process.
    # @return [Boolean]
    def daemonize?
      options[:daemonize] || false
    end

    # Path of the pidfile to create when running as a daemon.
    # @return [Pathname,String]
    def pidfile
      options[:pidfile] ||
        env['GOOD_JOB_PIDFILE'] ||
        Rails.application.root.join('tmp', 'pids', 'good_job.pid')
    end

    private

    def rails_config
      Rails.application.config.good_job
    end
  end
end
