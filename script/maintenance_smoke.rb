# frozen_string_literal: true

def wait_for_queue(message)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
  loop do
    complete = SolidQueue::Job.uncached do
      raise "queued maintenance execution failed" if SolidQueue::FailedExecution.exists?

      yield
    end
    return if complete
    raise message if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep 0.1
  end
end

probe_id_path = Rails.root.join("storage/.shutdown-probe-job")
if ARGV == [ "claim_shutdown_probe" ]
  job = MaintainProjectionsJob.new
  File.write(probe_id_path, job.job_id)
  File.write(Rails.root.join("storage/.shutdown-probe-requested"), job.job_id)
  job.enqueue
  raise "shutdown probe was not enqueued" unless job.successfully_enqueued?

  wait_for_queue("separate worker did not claim the shutdown probe within 30 seconds") do
    marker = Rails.root.join("storage/.shutdown-probe-started")
    marker.exist? && marker.read == job.job_id &&
      SolidQueue::ClaimedExecution.joins(:job).where(solid_queue_jobs: { active_job_id: job.job_id }).exists?
  end
  puts "Separate worker started the claimed maintenance shutdown probe."
  exit
elsif ARGV == [ "assert_released" ]
  job = SolidQueue::Job.find_by!(active_job_id: File.read(probe_id_path))
  raise "interrupted maintenance retained a claim" if job.claimed_execution.present?
  raise "interrupted maintenance failed" if job.failed_execution.present?
  raise "interrupted maintenance was neither completed nor released" unless job.finished? || job.ready_execution.present?

  puts "Interrupted maintenance completed or returned to its ready queue without a stale claim."
  exit
elsif ARGV == [ "assert_recovered" ]
  wait_for_queue("restarted worker did not complete interrupted maintenance within 30 seconds") do
    SolidQueue::Job.find_by!(active_job_id: File.read(probe_id_path)).finished?
  end
  puts "Restarted worker completed the interrupted maintenance job."
  exit
end

if ARGV == [ "assert_stopped" ]
  raise "stopped worker left claimed jobs behind" if SolidQueue::ClaimedExecution.exists?
  raise "stopped worker left registered processes behind" if SolidQueue::Process.exists?
  raise "worker execution failed" if SolidQueue::FailedExecution.exists?

  puts "Stopped worker released all claims and process registrations."
  exit
end

account = Account.create!(
  name: "Packaged maintenance smoke",
  current_balance: 100,
  balance_date: Date.current
)
rule = RecurringRule.create!(
  account: account,
  description: "Daily smoke projection",
  amount: 1,
  rule_type: :expense,
  frequency: :daily,
  anchor_date: Date.current,
  active: true
)
raise "recurring-rule persistence unexpectedly materialized projections" if rule.transactions.exists?

expired_login = AuditLog.create!(action: "login_failure", created_at: 91.days.ago)
financial_event = AuditLog.create!(action: "update", resource_type: "Account", resource_id: account.id, created_at: 1.year.ago)
jobs = [ MaintainProjectionsJob.perform_later, PruneAuthenticationAuditLogsJob.perform_later ]
raise "maintenance jobs were not enqueued" unless jobs.all?(&:successfully_enqueued?)

wait_for_queue("separate worker did not finish queued maintenance within 30 seconds") do
  SolidQueue::Job.where(active_job_id: jobs.map(&:job_id)).finished.count == jobs.length
end

expected_horizon = ProjectionMaterializer.horizon
raise "projection maintenance did not execute through its horizon" unless rule.transactions.maximum(:date) == expected_horizon
raise "authentication maintenance did not remove expired event" if AuditLog.exists?(expired_login.id)
raise "authentication maintenance removed financial history" unless AuditLog.exists?(financial_event.id)

puts "Separate worker completed queued maintenance and preserved financial history."
