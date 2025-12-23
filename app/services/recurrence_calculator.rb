class RecurrenceCalculator
  def initialize(rule)
    @rule = rule
  end

  def dates_until(end_date)
    start_date = [ @rule.anchor_date, Date.current ].max
    dates_between(start_date, end_date)
  end

  def dates_between(start_date, end_date)
    dates = []

    case @rule.frequency
    when "daily"
      dates = daily_dates(start_date, end_date)
    when "weekly"
      dates = weekly_dates(start_date, end_date)
    when "biweekly"
      dates = biweekly_dates(start_date, end_date)
    when "semimonthly"
      dates = semimonthly_dates(start_date, end_date)
    when "monthly"
      dates = monthly_dates(start_date, end_date)
    when "monthly_last"
      dates = monthly_last_dates(start_date, end_date)
    when "quarterly"
      dates = quarterly_dates(start_date, end_date)
    when "biyearly"
      dates = biyearly_dates(start_date, end_date)
    when "yearly"
      dates = yearly_dates(start_date, end_date)
    end

    dates.select { |d| d >= start_date && d <= end_date }
  end

  private

  def daily_dates(start_date, end_date)
    dates = []
    current = [ start_date, @rule.anchor_date ].max

    while current <= end_date
      dates << current
      current += 1.day
    end

    dates
  end

  def weekly_dates(start_date, end_date)
    dates = []
    target_wday = @rule.day_of_week || @rule.anchor_date.wday

    current = start_date
    current += 1.day until current.wday == target_wday
    current = @rule.anchor_date if @rule.anchor_date > start_date && @rule.anchor_date.wday == target_wday

    while current <= end_date
      dates << current
      current += 1.week
    end

    dates
  end

  def biweekly_dates(start_date, end_date)
    dates = []
    anchor = @rule.anchor_date

    current = anchor
    while current < start_date
      current += 2.weeks
    end

    while current <= end_date
      dates << current if current >= start_date
      current += 2.weeks
    end

    dates
  end

  def semimonthly_dates(start_date, end_date)
    dates = []
    first_day = @rule.day_of_month || 1
    second_day = 15

    current_month = start_date.beginning_of_month

    while current_month <= end_date
      first_occurrence = safe_date(current_month.year, current_month.month, first_day)
      second_occurrence = safe_date(current_month.year, current_month.month, second_day)

      dates << first_occurrence if first_occurrence >= start_date && first_occurrence <= end_date
      dates << second_occurrence if second_occurrence >= start_date && second_occurrence <= end_date

      current_month += 1.month
    end

    dates.sort
  end

  def monthly_dates(start_date, end_date)
    dates = []
    target_day = @rule.day_of_month || @rule.anchor_date.day

    current_month = start_date.beginning_of_month

    while current_month <= end_date
      occurrence = safe_date(current_month.year, current_month.month, target_day)
      dates << occurrence if occurrence >= start_date && occurrence <= end_date
      current_month += 1.month
    end

    dates
  end

  def monthly_last_dates(start_date, end_date)
    dates = []
    current_month = start_date.beginning_of_month

    while current_month <= end_date
      last_day = current_month.end_of_month
      dates << last_day if last_day >= start_date && last_day <= end_date
      current_month += 1.month
    end

    dates
  end

  def quarterly_dates(start_date, end_date)
    dates = []
    anchor = @rule.anchor_date

    current = anchor
    while current < start_date
      current += 3.months
    end

    while current <= end_date
      dates << current if current >= start_date
      current += 3.months
    end

    dates
  end

  def biyearly_dates(start_date, end_date)
    dates = []
    anchor = @rule.anchor_date

    current = anchor
    while current < start_date
      current += 6.months
    end

    while current <= end_date
      dates << current if current >= start_date
      current += 6.months
    end

    dates
  end

  def yearly_dates(start_date, end_date)
    dates = []
    anchor = @rule.anchor_date

    current = anchor
    while current < start_date
      current += 1.year
    end

    while current <= end_date
      dates << current if current >= start_date
      current += 1.year
    end

    dates
  end

  def safe_date(year, month, day)
    last_day = Date.new(year, month, -1).day
    Date.new(year, month, [ day, last_day ].min)
  end
end
