# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Build and run it with any OCI-compatible platform:
# docker build -t foresight .
# docker run -d -p 3000:8080 -v foresight_data:/rails/storage --name foresight foresight

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Keep this version in sync with .ruby-version. The digest pins the complete
# multi-architecture Debian 13 base identity. Refresh builds invalidate the
# named os-packages stage explicitly while normal source builds may reuse it.
FROM docker.io/library/ruby:3.4.11-slim-trixie@sha256:5b53e16f47e05acae56897d0f96b9d03dcb4563276e71c96415bf7777c9ba207 AS os-packages

ARG DEBIAN_FRONTEND=noninteractive

# Rails app lives here
WORKDIR /rails

# Upgrade inherited packages and install the one additional runtime library.
# apt metadata refresh, upgrade, install, and cleanup stay in one layer so a
# targeted --no-cache-filter os-packages build observes the current archive.
RUN apt-get update -qq && \
    apt-get upgrade --with-new-pkgs -y && \
    apt-get install --no-install-recommends -y libjemalloc2 && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set production environment variables and enable jemalloc for reduced memory usage and latency.
# Thruster listens on an unprivileged port so the image runs cleanly as a non-root user
# in Docker, Kubernetes, and other container runtimes.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    SOLID_QUEUE_IN_PUMA="true" \
    THRUSTER_HTTP_PORT="8080"

# Throw-away build stage to reduce size of final image
FROM os-packages AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock vendor ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

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

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Health check for container orchestration (Docker, Kubernetes, etc.)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD ["bin/container-healthcheck"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 8080
CMD ["./bin/thrust", "./bin/rails", "server"]
