# frozen_string_literal: true

Rails.application.config.after_initialize do
  connection = ActiveRecord::Base.connection
  next unless connection.data_source_exists?(Setting.table_name)
  next unless connection.column_exists?(Setting.table_name, :singleton_guard)

  Setting.ensure_instance!
end
