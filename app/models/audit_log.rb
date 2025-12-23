class AuditLog < ApplicationRecord
  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :logins, -> { where(action: %w[login_success login_failure]) }
  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }

  # Class methods for logging different actions
  class << self
    def log_login_success(request)
      create!(
        action: "login_success",
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(500)
      )
    end

    def log_login_failure(request, username: nil)
      create!(
        action: "login_failure",
        details: username.present? ? "Username: #{username}" : nil,
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(500)
      )
    end

    def log_create(resource, request)
      create!(
        action: "create",
        resource_type: resource.class.name,
        resource_id: resource.id,
        details: resource_summary(resource),
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(500)
      )
    end

    def log_update(resource, request, changes: nil)
      create!(
        action: "update",
        resource_type: resource.class.name,
        resource_id: resource.id,
        details: changes || resource.previous_changes.except("updated_at").to_json,
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(500)
      )
    end

    def log_delete(resource, request)
      create!(
        action: "delete",
        resource_type: resource.class.name,
        resource_id: resource.id,
        details: resource_summary(resource),
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(500)
      )
    end

    private

    def resource_summary(resource)
      case resource
      when Account
        "#{resource.name} (#{resource.account_type})"
      when Transaction
        "#{resource.description}: #{resource.formatted_amount} on #{resource.date}"
      when RecurringRule
        "#{resource.description}: #{resource.rule_type} #{resource.frequency}"
      else
        resource.to_s
      end
    end
  end
end
