# frozen_string_literal: true

class Rack::Attack
  # Use Rails cache for storing throttle data
  Rack::Attack.cache.store = Rails.cache

  # Throttle login attempts by IP address
  # Allow 10 requests per 15 minutes
  throttle("logins/ip", limit: 10, period: 15.minutes) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end

  # Throttle login attempts by username
  # Prevents attackers from trying many passwords against a single user
  throttle("logins/username", limit: 10, period: 15.minutes) do |req|
    if req.path == "/login" && req.post?
      # Normalize username to lowercase to prevent case-based bypass
      req.params["username"].to_s.downcase.presence
    end
  end

  # Block suspicious requests (common attack patterns)
  blocklist("block/bad-requests") do |req|
    # Block requests that look like they're trying to access sensitive files
    req.path =~ /\.(env|git|sql|bak|config)$/i
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"]
    now = match_data[:epoch_time]
    retry_after = match_data[:period] - (now % match_data[:period])

    [
      429,
      {
        "Content-Type" => "text/html",
        "Retry-After" => retry_after.to_s
      },
      [ <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Too Many Requests</title>
          <style>
            body { font-family: system-ui, sans-serif; padding: 40px; text-align: center; }
            h1 { color: #dc2626; }
          </style>
        </head>
        <body>
          <h1>Too Many Login Attempts</h1>
          <p>You have exceeded the maximum number of login attempts.</p>
          <p>Please try again in #{(retry_after / 60.0).ceil} minutes.</p>
        </body>
        </html>
      HTML
      ]
    ]
  end
end
