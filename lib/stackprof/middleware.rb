require 'fileutils'

module StackProf
  class Middleware
    def initialize(app, options = {})
      @app       = app
      @options   = options
      @num_reqs  = options[:save_every] || nil

      Middleware.mode     = options[:mode] || :cpu
      Middleware.interval = options[:interval] || 1000
      Middleware.enabled  = options[:enabled]
      Middleware.path     = options[:path] || 'tmp'
      Middleware.slower_than = options[:slower_than] || nil
      Middleware.faster_than = options[:faster_than] || nil
      at_exit{ Middleware.save } if options[:save_at_exit]
    end

    def call(env)
      enabled = Middleware.enabled?(env)
      StackProf.start(mode: Middleware.mode, interval: Middleware.interval) if enabled
      start = Time.now
      @app.call(env)
    ensure
      return unless enabled

      request_time = (Time.now - start) * 1000.0
      StackProf.stop
      if (Middleware.slower_than && request_time > Middleware.slower_than) || (Middleware.faster_than && request_time < Middleware.faster_than)
        Middleware.save
      end
    end

    class << self
      attr_accessor :enabled, :mode, :interval, :path, :slower_than, :faster_than

      def enabled?(env)
        if enabled.respond_to?(:call)
          enabled.call(env)
        else
          enabled
        end
      end

      def save(filename = nil)
        if results = StackProf.results
          FileUtils.mkdir_p(Middleware.path)
          filename ||= "stackprof-#{results[:mode]}-#{Process.pid}-#{Time.now.to_i}.dump"
          File.open(File.join(Middleware.path, filename), 'wb') do |f|
            f.write Marshal.dump(results)
          end
          filename
        end
      end

    end
  end
end
