# Request metadata passed to financial operations without an HTTP dependency.
AuditContext = Data.define(:remote_ip, :user_agent) do
  def self.from_request(request)
    new(remote_ip: request.remote_ip, user_agent: request.user_agent&.truncate(500))
  end
end
