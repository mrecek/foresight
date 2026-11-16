require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  include ApplicationHelper

  test "design buttons use native forms for destructive requests" do
    html = design_button("Delete", "/accounts/42", variant: :danger, method: :delete)
    assert_select Nokogiri::HTML.fragment(html), "form[action='/accounts/42'][method='post']" do
      assert_select "input[name='_method'][value='delete']"
      assert_select "button.btn-danger", text: "Delete"
    end
  end

  test "design navigation buttons remain ordinary links" do
    html = design_button("New Account", "/accounts/new", data: { turbo_frame: "_top" })
    assert_select Nokogiri::HTML.fragment(html), "a[href='/accounts/new'][data-turbo-frame='_top']", text: "New Account"
  end
end
