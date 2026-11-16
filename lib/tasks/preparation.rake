# Required installation data is prepared with the schema, never during inspection.
Rake::Task["db:prepare"].enhance do
  Setting.ensure_instance!
end
