# Optimize SQLite for production use with concurrent web requests.
# These settings significantly improve performance and reliability.

Rails.application.config.after_initialize do
  next unless ActiveRecord::Base.connection.adapter_name == "SQLite"

  ActiveRecord::Base.connection.execute <<~SQL
    PRAGMA journal_mode = WAL;
    PRAGMA synchronous = NORMAL;
    PRAGMA busy_timeout = 5000;
    PRAGMA cache_size = -20000;
    PRAGMA foreign_keys = ON;
    PRAGMA temp_store = MEMORY;
  SQL
end
