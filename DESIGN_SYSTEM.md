# Foresight Design System

Foresight uses server-rendered Rails views, reusable helpers, and Tailwind v4.
The authoritative theme, component classes, and utilities are in
[app/assets/tailwind/application.css](app/assets/tailwind/application.css).
Helper signatures live in
[app/helpers/application_helper.rb](app/helpers/application_helper.rb).

## Themes and color

The theme selector supports Dark, Light, and System. The selected preference is
stored in browser local storage; `data-theme` on the HTML element identifies the
resolved theme. Use semantic tokens so content works in both themes.

| Purpose | Classes |
| --- | --- |
| Page and cards | `bg-canvas`, `bg-surface`, `bg-surface-muted` |
| Text hierarchy | `text-content`, `text-secondary`, `text-muted`, `text-faint` |
| Borders | `border-line`, `border-line-strong` |
| Links and emphasis | `text-accent`, `text-accent-strong` |
| Income and positive states | `text-positive`, `bg-success-subtle` |
| Expenses and errors | `text-negative`, `bg-danger-subtle` |
| Warnings and estimates | `text-caution`, `bg-warning-subtle` |
| Highlighted surfaces | `bg-primary-subtle`, `bg-primary-muted` |

Fixed palette shades such as `primary-600` are available for deliberate accents
with known foreground/background contrast. Use theme tokens for semantic text,
borders, and surfaces. Validate new color combinations in both themes.

## Typography and spacing

| Class | Current font or role |
| --- | --- |
| `font-display` | Darker Grotesque with system sans-serif fallback; headings |
| `font-sans` | Tailwind's default system sans-serif stack; body text |
| `font-mono` | JetBrains Mono with monospace fallback; numbers and code |
| `text-money` | Tabular numbers with the mono font |

The layouts load Manrope, but it is not assigned to `font-sans`. Theme font
assignments belong in the CSS `@theme` block.

Use `gap-3` for compact controls, `gap-4` for ordinary spacing, and `gap-6` or
`gap-8` between sections. Pair `text-2xl`, `text-xl`, and `text-base` headings
with `font-display font-bold`; use `text-sm` for ordinary interface text and
`text-xs text-muted` for supporting text.

## Buttons and navigation

```erb
<%= design_button "View Account", account_path(@account), variant: :primary %>
<%= design_button "Cancel", accounts_path, variant: :secondary, size: :sm %>
<%= design_button "Delete", account_path(@account), variant: :danger, method: :delete %>
```

`design_button` renders a link for GET navigation, a form/button for other HTTP
methods, or a button when no path is supplied. Variants are `primary`,
`secondary`, `ghost`, `success`, and `danger`; sizes are `sm`, `base`, and `lg`.
Use a separate form for destructive actions rather than nesting forms.

Direct classes include `btn-primary`, `btn-secondary`, `btn-ghost`,
`btn-success`, `btn-danger`, `btn-sm`, and `btn-lg`.

Navigation within a Turbo frame must either return the same frame or explicitly
leave it. Dashboard links that open account or transaction pages use
`data: { turbo_frame: "_top" }`. Authentication responses to frame requests
require a full-page visit.

For icon actions, use `icon_button(icon:, path:, title:, variant:, method:, data:)`.
Supply a descriptive title. Navigation classes are `nav-link-active` and
`nav-link-inactive`.

## Forms

```erb
<%= form_with model: @account, class: "space-y-6" do |f| %>
  <div>
    <%= f.label :name, class: "form-label" %>
    <%= f.text_field :name, class: "form-input" %>
    <p class="form-hint">Choose a descriptive name.</p>
  </div>
  <div>
    <%= f.label :account_type, class: "form-label" %>
    <%= f.select :account_type, Account.account_types.keys, {}, class: "form-select" %>
  </div>
  <div class="flex justify-end gap-3 pt-4 border-t border-line">
    <%= design_button "Cancel", accounts_path, variant: :secondary %>
    <%= f.submit "Save", class: "btn-primary" %>
  </div>
<% end %>
```

Use `form-input-error` with `form-input` for invalid inputs and `form-error` for
error text. `toggle_switch(f, :active, label: "Active")` renders a boolean control.
Render validation errors with the submitted values intact.

## Status and financial labels

```erb
<%= badge "Active", variant: :success %>
<%= status_label estimated: transaction.estimated?, abbreviated: true %>
<%= transfer_badge transaction, show_account: true %>
<%= category_badge transaction.category %>
<%= format_money transaction.amount %>
```

`badge` variants include `success`, `warning`, `danger`, `primary`, and `neutral`.
`status_label` supplies a dot and the text Actual/Estimated (Act/Est when
abbreviated). Standalone dots use CSS classes, with visible adjacent status text:

```html
<span class="inline-flex items-center gap-1.5">
  <span class="status-dot-warning" aria-hidden="true"></span>
  <span>Needs review</span>
</span>
```

Available dot classes are `status-dot-success`, `status-dot-warning`, and
`status-dot-danger`. Status meaning must also be conveyed in text.

`money_amount(amount)` returns a number with two decimal places and separators;
`format_money` supplies currency, sign, and optional semantic coloring. For
custom markup, pair `text-money` with `text-positive` or `text-negative` according
to the amount's sign.

## Cards, alerts, and tables

Use `card`, `card-hover`, or `card-interactive` with explicit padding. Use
`alert_box "Saved", variant: :success` for feedback; alert classes include
`alert-info`, `alert-success`, `alert-warning`, and `alert-danger`.

```erb
<div class="table-container">
  <table class="table">
    <thead>
      <tr><th>Description</th><th class="text-right">Amount</th></tr>
    </thead>
    <tbody>
      <% @transactions.each do |transaction| %>
        <tr>
          <td><%= transaction.description %></td>
          <td class="text-right text-money"><%= format_money transaction.amount %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

Preserve semantic headings, associated form labels, keyboard focus, and readable
contrast. Exercise browser changes at desktop and mobile widths and in both
themes. Follow [CONTRIBUTING.md](CONTRIBUTING.md#validation) for validation.
