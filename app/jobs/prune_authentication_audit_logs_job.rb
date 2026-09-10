# frozen_string_literal: true

class PruneAuthenticationAuditLogsJob < ApplicationJob
  queue_as :maintenance

  def perform
    AuditLog.prune_expired_authentication_events!
  end
end
