# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Runtime and workflow contract", "bin/validate runtime"
  step "Style: Ruby", "bin/validate lint"
  step "Security: Ruby", "bin/validate security-ruby"
  step "Security: JavaScript", "bin/validate security-js"
  step "Architecture and migrations", "bin/validate architecture"
  step "Test: Full suite", "bin/validate test"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
