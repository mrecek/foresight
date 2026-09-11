class AuditLog < ApplicationRecord
  AUTHENTICATION_RETENTION = 90.days
  AUTHENTICATION_ACTIONS = %w[login_success login_failure login_denied].freeze

  validates :action, presence: true

  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :logins, -> { where(action: AUTHENTICATION_ACTIONS) }
  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }

  def self.prune_expired_authentication_events!(before: AUTHENTICATION_RETENTION.ago)
    logins.where(created_at: ...before).delete_all
  end

  # Class methods for logging different actions
  class << self
    def log_login_success(request, method: "password", issuer: nil, subject: nil)
      create!(
        action: "login_success",
        details: authentication_details(method:, issuer:, subject:),
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(500)
      )
    end

    def log_login_failure(request, method: "password", reason: nil, issuer: nil)
      create!(
        action: "login_failure",
        details: authentication_details(method:, issuer:, reason:),
        ip_address: request.remote_ip,
        user_agent: request.user_agent&.truncate(500)
      )
    end

    def log_login_denied(request, issuer:, subject:)
      create!(
        action: "login_denied",
        details: authentication_details(method: "oidc", issuer:, subject:, reason: "subject_not_allowed"),
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

    def authentication_details(method:, issuer: nil, subject: nil, reason: nil)
      return if method == "password"

      {
        method: method,
        issuer: issuer,
        subject_fingerprint: subject.present? ? OpenSSL::Digest::SHA256.hexdigest(subject).first(16) : nil,
        reason: reason
      }.compact.to_json
    end

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
