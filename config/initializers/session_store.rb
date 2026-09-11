# frozen_string_literal: true

Rails.application.config.session_store(
  :cookie_store,
  key: "_foresight_session",
  secure: Rails.env.production?,
  httponly: true,
  same_site: :lax
)
