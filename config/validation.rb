# frozen_string_literal: true

module Foresight
  module Validation
    STAGES = {
      "runtime" => [ [ "bin/check-runtime-parity" ], [ "bin/check-actions" ] ],
      "lint" => [ [ "bin/rubocop" ] ],
      "security-ruby" => [ [ "bin/security-audit", "ruby" ] ],
      "security-js" => [ [ "bin/security-audit", "javascript" ] ],
      "architecture" => [
        [ "bin/rails", "zeitwerk:check" ],
        [ "bin/rails", "db:prepare" ],
        [ "bin/rails", "db:migrate:status" ],
        [ "bin/transfers" ]
      ],
      "test" => [ [ "bin/test" ] ],
      "container" => [ [ "bin/container-check" ] ]
    }.freeze

    CI_STAGES = %w[runtime lint security-ruby security-js architecture test].freeze
    LOCAL_STAGES = (CI_STAGES + [ "container" ]).freeze
  end
end
