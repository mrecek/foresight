# Foresight Design System

## Overview

This design system provides a modern, minimal aesthetic for the Foresight application with a focus on clarity, sophistication, and usability for financial tracking.

### Design Principles

- **Financial Clarity**: Swiss-inspired minimalism meets modern fintech aesthetics
- **Distinctive Typography**: Custom font pairing for personality and hierarchy
- **Sophisticated Depth**: Subtle shadows and elevation for visual interest
- **Premium Interactions**: Polished micro-interactions that feel responsive

---

## Typography

### Font Families

```css
font-display   /* Darker Grotesque - For headings and emphasis */
font-sans      /* Manrope - For body text */
font-mono      /* JetBrains Mono - For numbers and code */
```

### Usage Examples

```erb
<h1 class="font-display font-bold text-2xl">Account Dashboard</h1>
<p class="font-sans text-base">Regular body text</p>
<span class="font-mono text-money">$1,234.56</span>
```

---

## Color Palette

### Semantic Colors

| Color    | Usage                          | Classes                       |
|----------|--------------------------------|-------------------------------|
| Primary  | Main actions, links, focus     | `bg-primary-600`, `text-primary-600` |
| Success  | Positive states, income        | `bg-success-600`, `text-success-600` |
| Warning  | Alerts, estimated transactions | `bg-warning-600`, `text-warning-600` |
| Danger   | Errors, negative balances      | `bg-danger-600`, `text-danger-600` |
| Neutral  | Text, borders, backgrounds     | `bg-neutral-100`, `text-neutral-700` |

### Color Scale

Each color has shades from 50 (lightest) to 950 (darkest):
- 50-200: Backgrounds
- 300-500: Borders, muted elements
- 600-700: Primary usage
- 800-950: Dark text, high contrast

---

## Components

### Buttons

Use the `design_button` helper or CSS classes directly.

#### Helper Method

```erb
<%= design_button "Save Changes", account_path, variant: :primary, size: :base %>
<%= design_button "Cancel", accounts_path, variant: :secondary %>
<%= design_button "Delete", account_path, variant: :danger, method: :delete %>
```

#### Variants

- `primary` - Main call-to-action (indigo with hover lift)
- `secondary` - Secondary actions (white with border)
- `ghost` - Subtle actions (transparent with hover background)
- `success` - Success actions (green)
- `danger` - Destructive actions (red)

#### Sizes

- `sm` - Small buttons
- `base` - Default size
- `lg` - Large buttons

#### Direct CSS Usage

```erb
<button class="btn-primary">Primary Button</button>
<button class="btn-secondary btn-sm">Small Secondary</button>
<a href="#" class="btn-ghost">Ghost Link</a>
```

---

### Form Controls

#### Input Fields

```erb
<!-- Using direct classes -->
<input type="text" class="form-input" placeholder="Enter amount" />

<!-- With error state -->
<input type="text" class="form-input form-input-error" />
```

#### Select Dropdowns

```erb
<select class="form-select">
  <option>Checking</option>
  <option>Savings</option>
</select>
```

#### Labels, Hints, and Errors

```erb
<label class="form-label">Account Name</label>
<input type="text" class="form-input" />
<p class="form-hint">Choose a descriptive name for your account</p>

<!-- Error state -->
<p class="form-error">This field is required</p>
```

#### Complete Form Example

```erb
<div>
  <%= f.label :name, class: "form-label" %>
  <%= f.text_field :name, class: "form-input", placeholder: "e.g., Main Checking" %>
  <p class="form-hint">Your verified balance from your bank</p>
</div>
```

---

### Toggle Switch

Create accessible toggle switches for boolean settings.

```erb
<%= toggle_switch(form, :active, label: "Active Status") %>
```

Custom implementation:

```erb
<label class="toggle">
  <input type="checkbox" class="sr-only" />
  <span class="toggle-slider"></span>
</label>
```

---

### Badges

Display status indicators and labels.

#### Using Helper

```erb
<%= badge "Active", variant: :success %>
<%= badge "Pending", variant: :warning %>
<%= badge "Inactive", variant: :neutral %>
```

#### Direct Classes

```erb
<span class="badge-success">ACT</span>
<span class="badge-warning">EST</span>
<span class="badge-danger">Error</span>
<span class="badge-primary">New</span>
<span class="badge-neutral">Draft</span>
```

---

### Status Dots

Small colored indicators for account status.

```erb
<%= status_dot variant: :success %>
<%= status_dot variant: :warning %>
<%= status_dot variant: :danger %>
```

Direct usage:

```erb
<span class="status-dot-success"></span>
<span class="status-dot-warning ring-2 ring-white"></span>
```

---

### Cards

Container components with consistent styling.

```erb
<!-- Basic card -->
<div class="card p-6">
  <h3 class="font-display font-bold">Card Title</h3>
  <p>Card content</p>
</div>

<!-- Hoverable card -->
<div class="card-hover p-6">
  <p>Hover to see shadow effect</p>
</div>

<!-- Interactive card (clickable) -->
<a href="#" class="card-interactive p-6">
  <p>Click me</p>
</a>
```

---

### Alerts/Notices

Display feedback messages with proper semantics.

#### Using Helper

```erb
<%= alert_box "Account created successfully!", variant: :success, dismissible: true %>
<%= alert_box "Please review these errors", variant: :danger %>
```

#### Direct Classes

```erb
<div class="alert-success">
  <div class="flex-1">Success message</div>
</div>

<div class="alert-danger">
  <div class="flex-1">Error message</div>
</div>
```

---

### Tables

Styled data tables with hover effects.

```erb
<div class="table-container">
  <table class="table">
    <thead>
      <tr>
        <th>Date</th>
        <th>Description</th>
        <th class="text-right">Amount</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>Jan 15, 2024</td>
        <td>Grocery Store</td>
        <td class="text-right text-money text-danger-600">-$45.23</td>
      </tr>
    </tbody>
  </table>
</div>
```

---

## Layout Components

### Navigation

```erb
<!-- Active nav link -->
<%= link_to "Dashboard", root_path, class: "nav-link-active" %>

<!-- Inactive nav link -->
<%= link_to "Settings", settings_path, class: "nav-link-inactive" %>
```

---

## Utility Classes

### Money/Number Formatting

```erb
<span class="text-money">$1,234.56</span>
<span class="text-money text-success-600">+$500.00</span>
```

### Shadows

```css
shadow-soft       /* Subtle shadow for cards */
shadow-soft-lg    /* Larger shadow for elevated elements */
shadow-inner-soft /* Inner shadow for inputs */
```

### Border Radius

```css
rounded-sm    /* 0.375rem */
rounded       /* 0.5rem - default */
rounded-lg    /* 0.75rem */
rounded-xl    /* 1rem */
rounded-2xl   /* 1.5rem */
```

### Animations

```css
animate-slide-up     /* Slide up with fade */
animate-slide-down   /* Slide down with fade */
animate-fade-in      /* Simple fade in */
animate-scale-in     /* Scale up with fade */
```

---

## Helper Methods Reference

### ApplicationHelper Methods

| Method | Purpose | Example |
|--------|---------|---------|
| `design_button` | Styled buttons/links | `design_button "Save", path, variant: :primary` |
| `badge` | Status badges | `badge "Active", variant: :success` |
| `status_dot` | Status indicator dots | `status_dot variant: :warning` |
| `alert_box` | Alert messages | `alert_box "Success!", variant: :success` |
| `toggle_switch` | Toggle switches | `toggle_switch form, :active` |

---

## Best Practices

### 1. Use Semantic Colors

```erb
<!-- Good: Semantic meaning -->
<span class="text-success-600">+$100</span>
<span class="text-danger-600">-$50</span>

<!-- Avoid: Generic colors -->
<span class="text-green-600">+$100</span>
```

### 2. Consistent Spacing

Use the spacing scale consistently:
- `gap-3` / `space-y-3` for tight spacing
- `gap-4` / `space-y-4` for comfortable spacing
- `gap-6` / `space-y-6` for section spacing
- `gap-8` / `space-y-8` for major section breaks

### 3. Typography Hierarchy

```erb
<h1 class="text-2xl font-display font-bold">Main Heading</h1>
<h2 class="text-xl font-display font-bold">Section Heading</h2>
<h3 class="text-base font-display font-bold">Subsection</h3>
<p class="text-sm">Body text</p>
<p class="text-xs text-neutral-500">Helper text</p>
```

### 4. Interactive States

Always include hover, focus, and active states:

```erb
<button class="bg-primary-600 hover:bg-primary-700 active:bg-primary-800 focus:ring-2 focus:ring-primary-500">
  Click me
</button>
```

### 5. Accessibility

- Use semantic HTML
- Include proper labels for form controls
- Ensure sufficient color contrast
- Add keyboard navigation support

---

## Migration Guide

### Updating Existing Components

**Before:**
```erb
<button class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded-md">
  Save
</button>
```

**After:**
```erb
<%= design_button "Save", path, variant: :primary %>
<!-- OR -->
<button class="btn-primary">Save</button>
```

**Before:**
```erb
<input class="block w-full rounded-md border-gray-300 focus:border-indigo-500" />
```

**After:**
```erb
<input class="form-input" />
```

**Before:**
```erb
<div class="bg-white rounded-lg shadow p-6">Content</div>
```

**After:**
```erb
<div class="card p-6">Content</div>
```

---

## Example Compositions

### Complete Form Pattern

```erb
<div class="card p-6">
  <h2 class="text-xl font-display font-bold mb-6">Create Account</h2>

  <%= form_with model: @account, class: "space-y-6" do |f| %>
    <div>
      <%= f.label :name, class: "form-label" %>
      <%= f.text_field :name, class: "form-input", placeholder: "Main Checking" %>
      <p class="form-hint">Choose a descriptive name</p>
    </div>

    <div>
      <%= f.label :account_type, class: "form-label" %>
      <%= f.select :account_type, [...], class: "form-select" %>
    </div>

    <div class="flex justify-end gap-3 pt-4 border-t border-neutral-200">
      <%= design_button "Cancel", accounts_path, variant: :secondary %>
      <%= f.submit class: "btn-primary cursor-pointer" %>
    </div>
  <% end %>
</div>
```

### Data Table with Actions

```erb
<div class="card">
  <div class="px-6 py-5 border-b border-neutral-200">
    <h2 class="text-xl font-display font-bold">Transactions</h2>
  </div>

  <div class="overflow-x-auto">
    <table class="table">
      <thead>
        <tr>
          <th>Status</th>
          <th>Date</th>
          <th>Description</th>
          <th class="text-right">Amount</th>
        </tr>
      </thead>
      <tbody>
        <% @transactions.each do |txn| %>
          <tr>
            <td><%= badge txn.status, variant: :success %></td>
            <td class="font-medium"><%= txn.date %></td>
            <td><%= txn.description %></td>
            <td class="text-right text-money text-success-600">
              <%= txn.formatted_amount %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

---

## Support

For questions or issues with the design system, refer to:
- Tailwind config: `config/tailwind.config.js`
- Custom CSS: `app/assets/tailwind/application.css`
- Helper methods: `app/helpers/application_helper.rb`
