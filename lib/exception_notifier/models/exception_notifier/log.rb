class ExceptionNotifier::Log
  
  include MongoMapper::Document
  timestamps!
  
  key :message, String
  key :exception_type, String
  
  key :backtrace, String
  key :environment, String
  key :session, String
  
  key :request_url, String
  key :request_ip_address, String
  key :request_params, String
  
  key :session_id, String
  key :session_data, String
  
  key :token, String

  
  def self.persist env, exception
    
    @env        = env
    @exception  = exception
    @request    = ActionDispatch::Request.new(env)
    
    log = self.new
    
    log.message = exception.message
    log.exception_type = exception.class.to_s
    log.backtrace  = exception.backtrace.join("\n")
    
    log.request_url = @request.url
    log.request_ip_address = @request.remote_ip
    log.request_params = @request.filtered_parameters
    
    log.session_id = @request.ssl? ? "[FILTERED]" : (@request.session['session_id'] || @request.env["rack.session.options"][:id])
    log.session_data = @request.session
    
    log.token = @request.session["token"]
    
    log.save!
  end
  
end