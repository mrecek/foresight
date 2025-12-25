module ApplicationHelper
  # Button helper with design system styles
  def design_button(text, path = nil, variant: :primary, size: :base, method: :get, **options)
    size_class = size == :sm ? "btn-sm" : (size == :lg ? "btn-lg" : "")
    variant_class = "btn-#{variant}"

    css_class = [ variant_class, size_class, options[:class] ].compact.join(" ")

    if path
      link_to text, path, class: css_class, method: method, **options.except(:class)
    else
      content_tag :button, text, class: css_class, **options.except(:class)
    end
  end

  # Form field wrapper with label, input, and error/hint display
  def form_field(form, field, label: nil, hint: nil, type: :text_field, **options)
    label_text = label || field.to_s.titleize
    has_errors = form.object.errors[field].any?

    input_class = has_errors ? "form-input form-input-error" : "form-input"
    input_class = [ input_class, options[:class] ].compact.join(" ")

    content_tag :div, class: "form-group" do
      concat form.label(field, label_text, class: "form-label")

      # Render the appropriate input type
      case type
      when :select
        concat form.select(field, options[:choices] || [], options[:select_options] || {},
                          class: "form-select #{has_errors ? 'form-input-error' : ''}")
      when :text_area
        concat form.text_area(field, class: input_class, rows: options[:rows] || 4, **options.except(:class, :rows))
      else
        concat form.send(type, field, class: input_class, **options.except(:class))
      end

      # Show error or hint
      if has_errors
        concat content_tag(:div, form.object.errors[field].join(", "), class: "form-error")
      elsif hint
        concat content_tag(:div, hint, class: "form-hint")
      end
    end
  end

  # Toggle switch component
  def toggle_switch(form, field, label: nil, **options)
    label_text = label || field.to_s.titleize
    toggle_id = "#{form.object_name}_#{field}_toggle"

    content_tag :div, class: "flex items-center justify-between" do
      concat content_tag(:span, label_text, class: "form-label mb-0")
      concat content_tag(:label, class: "toggle") do
        concat form.check_box(field, { class: "sr-only", id: toggle_id }, **options)
        concat content_tag(:span, "", class: "toggle-slider")
      end
    end
  end

  # Badge component
  def badge(text, variant: :neutral, **options)
    css_class = [ "badge-#{variant}", options[:class] ].compact.join(" ")
    content_tag :span, text, class: css_class, **options.except(:class)
  end

  # Status dot
  def status_dot(variant: :success)
    content_tag :span, "", class: "status-dot-#{variant}"
  end

  # Transfer badge - shows a transfer indicator with optional linked account info
  def transfer_badge(transaction, show_account: false)
    return nil unless transaction.transfer?

    icon = '<svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4"/></svg>'

    if show_account && transaction.linked_transaction
      linked_account = transaction.linked_transaction.account
      direction = transaction.amount < 0 ? "→" : "←"
      label = "#{direction} #{linked_account.name}"
    else
      label = "Transfer"
    end

    content_tag :span, class: "inline-flex items-center gap-1 text-xs font-medium text-primary-600 bg-primary-50 px-2 py-0.5 rounded-full" do
      icon.html_safe + " " + label
    end
  end

  # Category badge - pill-shaped badge for transaction categories (distinct from semantic badges)
  def category_badge(category)
    return nil unless category

    color = category.color
    css_class = "category-badge-#{color}"

    # Small tag icon to differentiate from status badges
    tag_icon = '<svg class="w-3 h-3" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/></svg>'

    content_tag :span, class: css_class do
      tag_icon.html_safe + category.name
    end
  end

  # Alert/Notice component
  def alert_box(message = nil, variant: :info, dismissible: false, **options, &block)
    css_class = [ "alert-#{variant}", options[:class] ].compact.join(" ")

    content_tag :div, class: css_class, role: "alert", **options.except(:class) do
      if block_given?
        yield
      else
        concat content_tag(:div, message, class: "flex-1")
      end
      if dismissible
        concat content_tag(:button, "×",
                          class: "text-current opacity-50 hover:opacity-100 text-xl leading-none",
                          onclick: "this.parentElement.remove()")
      end
    end
  end

  # Icon button for table actions
  def icon_button(icon:, path: nil, title:, variant: :default, method: :get, data: {}, **options)
    icon_svg = case icon
    when :view
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>'
    when :edit
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>'
    when :delete
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>'
    when :check
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>'
    when :more
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/></svg>'
    else
      icon.to_s
    end

    base_classes = "inline-flex items-center justify-center w-10 h-10 rounded-lg transition-all duration-150"
    variant_classes = case variant
    when :danger
      "text-neutral-400 hover:text-danger-600 hover:bg-danger-50"
    when :success
      "text-neutral-400 hover:text-success-600 hover:bg-success-50"
    when :primary
      "text-neutral-400 hover:text-primary-600 hover:bg-primary-50"
    else
      "text-neutral-400 hover:text-neutral-600 hover:bg-neutral-100"
    end

    css_class = [ base_classes, variant_classes, options[:class] ].compact.join(" ")

    if path
      if method == :delete || method == :post || method == :patch
        button_to path, method: method, data: data, class: css_class, title: title, **options.except(:class) do
          icon_svg.html_safe
        end
      else
        link_to path, class: css_class, title: title, data: data, **options.except(:class) do
          icon_svg.html_safe
        end
      end
    else
      content_tag :button, icon_svg.html_safe, class: css_class, title: title, type: "button", data: data, **options.except(:class)
    end
  end

  # Dropdown menu component
  def dropdown_menu(button_content: nil, **options, &block)
    content_tag :div, class: "relative inline-block", data: { controller: "dropdown" } do
      # Trigger button
      trigger = content_tag :button,
        button_content || icon_button_svg(:more),
        type: "button",
        class: "inline-flex items-center justify-center w-10 h-10 rounded-lg text-neutral-400 hover:text-neutral-600 hover:bg-neutral-100 transition-all duration-150",
        data: { dropdown_target: "button", action: "click->dropdown#toggle" },
        "aria-expanded": "false",
        "aria-haspopup": "true"

      # Dropdown menu
      menu = content_tag :div,
        class: "absolute right-0 z-10 mt-1 w-48 origin-top-right rounded-xl bg-white shadow-soft-lg ring-1 ring-neutral-200 transition-all duration-150 opacity-0 scale-95 pointer-events-none",
        data: { dropdown_target: "menu" },
        role: "menu" do
          content_tag :div, class: "py-1", &block
        end

      trigger + menu
    end
  end

  # Dropdown menu item
  def dropdown_item(text, path, icon: nil, variant: :default, method: :get, data: {}, **options)
    icon_svg = case icon
    when :view
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/><path stroke-linecap="round" stroke-linejoin="round" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/></svg>'
    when :edit
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/></svg>'
    when :delete
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>'
    when :check
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7"/></svg>'
    else
      nil
    end

    variant_classes = case variant
    when :danger
      "text-danger-600 hover:bg-danger-50"
    when :success
      "text-success-600 hover:bg-success-50"
    else
      "text-neutral-700 hover:bg-neutral-50"
    end

    base_classes = "flex items-center gap-2 w-full px-4 py-2 text-sm transition-colors duration-150"
    css_class = [ base_classes, variant_classes ].join(" ")

    if method == :delete || method == :post || method == :patch
      button_to path, method: method, data: data, class: css_class, role: "menuitem", **options do
        safe_join([ icon_svg&.html_safe, text ].compact)
      end
    else
      link_to path, class: css_class, data: data, role: "menuitem", **options do
        safe_join([ icon_svg&.html_safe, text ].compact)
      end
    end
  end

  # Format money with proper currency display
  def format_money(amount, show_sign: true, color: true)
    formatted = number_to_currency(amount.to_f.abs, precision: 2)
    sign = amount.to_f >= 0 ? "+" : "-"

    if show_sign
      display = "#{sign}#{formatted.gsub('$', '')}".gsub("+", "+$").gsub("-", "-$")
    else
      display = formatted
    end

    if color
      css_class = amount.to_f >= 0 ? "text-success-600" : "text-danger-600"
      content_tag :span, display, class: "font-mono tabular-nums #{css_class}"
    else
      content_tag :span, display, class: "font-mono tabular-nums"
    end
  end

  # Format a number as currency with 2 decimal places and thousand separators
  def money_amount(amount)
    number_with_delimiter(sprintf("%.2f", amount.to_f), delimiter: ",")
  end
end
