module ReturnNavigation
  extend ActiveSupport::Concern

  private

  def safe_return_url(fallback:)
    url_from(params[:return_url].presence) || url_from(request.referer) || fallback
  end
end
