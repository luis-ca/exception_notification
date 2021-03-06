require 'action_dispatch'
require 'exception_notifier/notifier'
require 'exception_notifier/models/exception_notifier/log'

class ExceptionNotifier
  def self.default_ignore_exceptions
    [].tap do |exceptions|
      exceptions << ::ActiveRecord::RecordNotFound if defined? ::ActiveRecord::RecordNotFound
      exceptions << ::AbstractController::ActionNotFound if defined? ::AbstractController::ActionNotFound
      exceptions << ::ActionController::RoutingError if defined? ::ActionController::RoutingError
    end
  end

  def self.default_ignore_crawlers
    []
  end

  def initialize(app, options = {})
    @app, @options = app, options

    Notifier.default_sender_address       = @options[:sender_address]
    Notifier.default_exception_recipients = @options[:exception_recipients]
    Notifier.default_email_prefix         = @options[:email_prefix]
    Notifier.default_sections             = @options[:sections]
    Notifier.default_background_sections  = @options[:background_sections]
    Notifier.default_verbose_subject      = @options[:verbose_subject]
    Notifier.default_normalize_subject    = @options[:normalize_subject]

    @options[:ignore_exceptions] ||= self.class.default_ignore_exceptions
    @options[:ignore_crawlers]   ||= self.class.default_ignore_crawlers
    @options[:ignore_if]         ||= lambda { |e| false }
  end

  def call(env)
    @app.call(env)
  rescue Exception => exception
    options = (env['exception_notifier.options'] ||= Notifier.default_options)
    options.reverse_merge!(@options)

    unless ignored_exception(options[:ignore_exceptions], exception)       ||
           from_crawler(options[:ignore_crawlers], env['HTTP_USER_AGENT']) ||
           options[:ignore_if].call(exception)
      Notifier.exception_notification(env, exception).deliver
      env['exception_notifier.delivered'] = true
    end

    raise exception
  end

  private

  def ignored_exception(ignore_array, exception)
    Array.wrap(ignore_array).include?(exception.class)
  end

  def from_crawler(ignore_array, agent)
    ignore_array.each do |crawler|
      return true if (agent =~ Regexp.new(crawler))
    end unless ignore_array.blank?
    false
  end
end
