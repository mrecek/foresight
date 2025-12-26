class CapSessionTimeout < ActiveRecord::Migration[8.1]
  def up
    # Cap any session timeouts over 1440 minutes to 1440
    Setting.where("session_timeout_minutes > 1440").update_all(session_timeout_minutes: 1440)
  end

  def down
    # No-op - we don't know original values
  end
end
