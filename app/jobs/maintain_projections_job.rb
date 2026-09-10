# frozen_string_literal: true

class MaintainProjectionsJob < ApplicationJob
  queue_as :maintenance

  def perform
    ProjectionMaterializer.materialize_all
  end
end
