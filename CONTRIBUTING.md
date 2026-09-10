# Contributing to Foresight

👋 Thanks for checking out Foresight!

**Please Note:** This is primarily a personal project that I maintain for my own use. While I've made the code public in hopes that it might be useful to others, I am not actively seeking major feature contributions at this time.

## Expectations

- **Bug Reports**: You are welcome to open issues for bugs you encounter. I appreciate the heads-up!
- **Feature Requests**: You can suggest features, but please understand that I will likely only implement them if they align with my own roadmap and needs.
- **Pull Requests**: Please **open an issue to discuss your changes first** before opening a PR. I may not merge PRs that add complexity or features I don't intend to maintain long-term.

## Code of Conduct

Be kind and respectful. This is a free, open-source tool shared in good faith.

## Development

To build the project locally:

```bash
bundle install
bin/rails db:setup
bin/dev
```

Visit `http://localhost:3000`.

For demo data and authentication-free local testing:

```bash
SEED_DEMO_DATA=true bin/rails db:seed
TEST_MODE=true bin/dev
```

To validate a change locally before opening a PR:

```bash
bin/validate
```

This is the complete contract: runtime and workflow parity, style, refreshed
Ruby and JavaScript security audits, autoloading, migration state, the full test
suite, and a production-container build and smoke check. Run a named stage such
as `bin/validate test` for a faster focused check, or `bin/validate --ci` for the
non-container stages used by pull-request CI.

Run `bin/rails test:system` to exercise only the deliberately small real-browser
suite. It covers authentication, transfers, recurring transfers,
reconciliation, Turbo navigation, and the principal Stimulus form interactions.
Failures save screenshots under `tmp/system-test-artifacts`; CI uploads that
directory when the test job fails.

Ruby patch freshness is checked monthly against the official Ruby repository.
Patch updates move `.ruby-version` and the digest-pinned Docker base together;
Dependabot separately proposes digest-only base rebuilds so operating-system
fixes are not tied to application changes. Ruby major and minor upgrades remain
an explicit architecture decision.

Container delivery treats each pushed image as an unpromoted, run-specific
candidate. Both supported architectures are smoke-tested and provenance is
verified before the immutable release, dated channel, and `latest` are promoted;
the full commit-SHA tag is written last as the completion marker. Daily
reconciliation verifies and repairs partial promotion. Candidate tags are kept
as immutable audit references.
