# syntax=docker/dockerfile:1
# check=error=true

# Production OCI image. See docs/deployment.md for the web/jobs container contract,
# shared local SQLite storage, preparation, and shutdown requirements.

# This pinned base also declares the Ruby version used by local mise and CI. The digest pins the complete
# multi-architecture Debian 13 base identity. Release builds invalidate the
# os-packages stage so package refreshes are independent of source changes.
FROM docker.io/library/ruby:3.4.12-slim-trixie@sha256:65680693964528b522a38d85ec5065538c7ab9e75268802aab9770f39ee56de0 AS os-packages

ARG DEBIAN_FRONTEND=noninteractive

# Rails app lives here
WORKDIR /rails

# Upgrade inherited packages and install the runtime library and process init.
# apt metadata refresh, upgrade, install, and cleanup stay in one layer so a
# release cache filters rebuild this stage and the final runtime, preventing
# imported runtime layers from restoring a previous refresh.
RUN apt-get update --error-on=any -qq && \
    apt-get upgrade --with-new-pkgs -y && \
    apt-get install --no-install-recommends -y libjemalloc2 tini && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives && \
    date -u +%Y-%m-%dT%H:%M:%SZ > /usr/local/share/foresight-os-refreshed-at

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
# Puma listens on an unprivileged port so the image runs cleanly as a non-root user
# in Docker, Kubernetes, and other container runtimes.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    PORT="8080"

# Throw-away build stage to reduce size of final image
FROM os-packages AS build

# Install packages needed to build gems
RUN apt-get update --error-on=any -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN test ! -d /rails/bundle && \
    test ! -d /rails/vendor/bundle && \
    bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails tailwindcss:build assets:precompile

# Final stage for app image
FROM os-packages AS runtime

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin
USER 1000:1000

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

# Tini forwards startup signals and reaps children; the entrypoint prepares web databases.
ENTRYPOINT ["/usr/bin/tini", "--", "/rails/bin/docker-entrypoint"]

# Health check for container orchestration (Docker, Kubernetes, etc.)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["bin/container-healthcheck"]

# Start the web process; a second container runs bin/jobs against the same storage.
EXPOSE 8080
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
