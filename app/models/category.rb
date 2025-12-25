class Category < ApplicationRecord
  belongs_to :category_group
  has_many :transactions, dependent: :nullify
  has_many :recurring_rules, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :category_group_id, case_sensitive: false }

  scope :ordered, -> { order(:display_order, :name) }

  delegate :color, to: :category_group

  # Returns a default "Uncategorized" category, creating it if needed
  def self.uncategorized
    uncategorized_group = CategoryGroup.uncategorized
    uncategorized_group.categories.find_or_create_by!(name: "Uncategorized") do |cat|
      cat.display_order = 999
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end
end
