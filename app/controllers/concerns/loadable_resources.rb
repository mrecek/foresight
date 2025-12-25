module LoadableResources
  extend ActiveSupport::Concern

  private

  def load_accounts
    @accounts = Account.all
  end

  def load_categories
    @categories = Category.includes(:category_group).ordered
  end
end
