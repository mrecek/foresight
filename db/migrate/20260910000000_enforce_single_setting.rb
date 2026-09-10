class EnforceSingleSetting < ActiveRecord::Migration[8.1]
  SINGLETON_GUARD = 1

  def up
    resolve_existing_settings

    add_column :settings, :singleton_guard, :integer, null: false, default: SINGLETON_GUARD
    add_check_constraint :settings, "singleton_guard = #{SINGLETON_GUARD}", name: "settings_singleton_guard"
    add_index :settings, :singleton_guard, unique: true, name: "index_settings_on_singleton_guard"

    create_default_setting unless setting_exists?
  end

  def down
    remove_index :settings, name: "index_settings_on_singleton_guard"
    remove_check_constraint :settings, name: "settings_singleton_guard"
    remove_column :settings, :singleton_guard
  end

  private

  def resolve_existing_settings
    rows = select_all(<<~SQL).to_a
      SELECT id, auth_username, auth_password_digest, created_at
      FROM settings
      ORDER BY created_at ASC, id ASC
    SQL
    return if rows.size <= 1

    winner = rows.min_by do |row|
      credentials_complete = row["auth_username"].present? && row["auth_password_digest"].present?
      [ credentials_complete ? 0 : 1, row["created_at"].to_s, row["id"].to_i ]
    end
    discarded_ids = rows.map { |row| row["id"].to_i } - [ winner["id"].to_i ]

    say "Found #{rows.size} settings rows; keeping id=#{winner['id']} and removing ids=#{discarded_ids.join(',')}. " \
      "A complete credential row takes precedence, then the earliest created row and lowest id."
    execute "DELETE FROM settings WHERE id != #{connection.quote(winner['id'])}"
  end

  def setting_exists?
    select_value("SELECT 1 FROM settings LIMIT 1").present?
  end

  def create_default_setting
    now = connection.quote(Time.current)
    execute <<~SQL
      INSERT INTO settings
        (default_view_months, session_timeout_minutes, singleton_guard, created_at, updated_at)
      VALUES
        (3, 30, #{SINGLETON_GUARD}, #{now}, #{now})
    SQL
  end
end
