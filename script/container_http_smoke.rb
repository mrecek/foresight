# frozen_string_literal: true

require "cgi"
require "net/http"
require "uri"

# Exercise the real production HTTP stack through a TLS proxy's forwarded headers.
http = Net::HTTP.new("127.0.0.1", ENV.fetch("PORT", "8080").to_i)
http.open_timeout = 3
http.read_timeout = 10
headers = {
  "Host" => "internal.example.test",
  "X-Forwarded-Host" => "foresight.example.test",
  "X-Forwarded-Proto" => "https"
}

protected_response = http.get("/", headers)
raise "private application did not require login" unless protected_response.is_a?(Net::HTTPRedirection)
raise "forwarded HTTPS origin was lost" unless protected_response["location"] == "https://foresight.example.test/login"

login = http.get("/login", headers)
raise "login page failed" unless login.is_a?(Net::HTTPSuccess)
asset_path = login.body[%r{href="(/assets/[^"?]+\.css)"}, 1]
raise "login page has no compiled stylesheet" unless asset_path

asset = http.get(asset_path, headers)
raise "compiled asset was not served intact" unless asset.is_a?(Net::HTTPSuccess) &&
  asset.body == File.binread(File.join("public", asset_path.delete_prefix("/")))
raise "compiled asset lost its public cache lifetime" unless asset["cache-control"].to_s.include?("public") &&
  asset["cache-control"].to_s[/max-age=(\d+)/, 1].to_i >= 365 * 24 * 60 * 60

%w[/storage/.secret_key_base /storage/production.sqlite3 /config/master.key].each do |path|
  response = http.get(path, headers)
  raise "private file was exposed at #{path}" unless response.is_a?(Net::HTTPNotFound)
end

csrf_token = login.body[/name="csrf-token" content="([^"]+)"/, 1]
raise "login CSRF token missing" unless csrf_token
cookie = login.get_fields("set-cookie").to_a.map { |value| value.split(";", 2).first }.join("; ")
request = Net::HTTP::Post.new("/login", headers.merge("Cookie" => cookie, "Origin" => "https://foresight.example.test"))
request.set_form_data(
  "authenticity_token" => CGI.unescapeHTML(csrf_token),
  "username" => ENV.fetch("AUTH_USERNAME"),
  "password" => ENV.fetch("AUTH_PASSWORD")
)
authenticated = http.request(request)
raise "password login failed" unless authenticated.is_a?(Net::HTTPRedirection) &&
  authenticated["location"] == "https://foresight.example.test/"
session_cookie = authenticated.get_fields("set-cookie").to_a.find { |value| value.start_with?("_foresight_session=") }
raise "production session cookie is not secure and HTTP-only" unless session_cookie&.match?(/; secure/i) &&
  session_cookie.match?(/; httponly/i)

dashboard = http.get("/", headers.merge("Cookie" => session_cookie.split(";", 2).first))
raise "authenticated dashboard failed" unless dashboard.is_a?(Net::HTTPSuccess) && dashboard.body.include?("Dashboard")

puts "Production HTTP passed: assets, authentication, forwarded HTTPS, secure cookies, and private storage protection."
