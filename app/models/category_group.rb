class CategoryGroup < ApplicationRecord
  COLORS = %w[teal purple rose orange sky lime fuchsia slate].freeze

  has_many :categories, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :color, presence: true, inclusion: { in: COLORS }
  validates :display_order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:display_order, :name) }

  # Returns a default "Uncategorized" group, creating it if needed
  def self.uncategorized
    find_or_create_by!(name: "Uncategorized") do |group|
      group.color = "slate"
      group.display_order = 999
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
