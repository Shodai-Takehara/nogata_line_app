# frozen_string_literal: true

class FetchCampReservationsJob < ApplicationJob
  queue_as :default

  BASE_URL = 'https://nogata-camp.info/reserve'.freeze

  def perform(start_date: Time.zone.today, end_date: Time.zone.today.next_month.end_of_month)
    agent = Mechanize.new
    agent.user_agent_alias = 'Windows Chrome'

    campground = Campground.find_by!(name: '直方キャンプ場')
    sites      = Site.where(campground: campground).order(:site_no)
    execution  = ReservationJobExecution.create!(campground: campground, executed_at: Time.zone.now)

    date = start_date
    while date <= end_date
      from_date = date
      to_date = [ date + 3.days, end_date ].min
      fetch_and_save_slots(agent, campground, execution, from_date, to_date, sites, end_date)
      date += 4.days
    end
  end

  private

  def extract_date_from_th(th)
    return nil unless th

    year = th.at('.year')&.text&.strip =~ /(\d{4})年/ ? $1.to_i : Time.zone.today.year
    if th.at('.month')&.text&.strip =~ /(\d{1,2})月(\d{1,2})日/
      month = $1.to_i
      day = $2.to_i
      Date.new(year, month, day) rescue nil
    end
  end

  def date_in_range?(date, from_date, to_date, end_date)
    date && date >= from_date && date <= to_date && date <= end_date
  end

  def fetch_and_save_slots(agent, campground, execution, from_date, to_date, sites, end_date)
    params = { reserveDate: from_date.to_s, _: (Time.now.to_f * 1000).to_i }
    page   = agent.get("#{BASE_URL}/reserve-site/selectDate", params)
    json   = JSON.parse(page.body)
    html   = json.dig('data', 'reflash')
    doc    = Nokogiri::HTML(html)

    table = doc.at('table.calendar__site__table')
    tbody = table&.at('tbody')
    date_tr_pairs = []
    return unless tbody

    tds = doc.css('tbody tr.calendar__time').first.css('td')
    File.open(Rails.root.join('camp.txt'), 'a') { |f| f.puts tds.inspect }
    date_tr_pairs << [ from_date, tds ]
    rows = tbody.children.select { |node| node.element? }

    if rows.any? { |row| row.at('th')&.[]('class')&.include?('calendar__change-month') }
      i = 0
      while i < rows.size
        row = rows[i]
        if row.name == 'tr' && row.at('th')&.[]('class')&.include?('calendar__change-month')
          date = extract_date_from_th(row.at('th'))
          i += 1
          trs = []
          while i < rows.size && rows[i].name == 'tr' && rows[i]['class'].to_s.include?('calendar__time')
            trs << rows[i]
            i += 1
          end
          date_tr_pairs << [date, trs]
        else
          i += 1
        end
      end
    end

    date_tr_pairs.each do |date, trs|
      next unless date_in_range?(date, from_date, to_date, end_date)
      trs.each do |time_row|
        time = time_row.at('td')&.text&.strip
        next if time.nil? || time.empty? || time == '--:--'

        normalized_time_slot = Time.zone.parse("2000-01-01 #{time}")
        time_row.css('td').each_with_index do |td, idx|
          site_no = td['data-siteid']&.to_i
          next unless site_no

          site = sites.find { |s| s.site_no == site_no }
          next unless site

          status = td['class']&.include?('calendar__time--open') ? :open : :close
          ReservationSlot.find_or_create_by!(
            reservation_job_execution: execution,
            site: site,
            date: date,
            time_slot: normalized_time_slot
          ) { |slot| slot.status = status }
        end
      end
      # camp.txt出力
      sites.each do |site|
        slots = ReservationSlot.where(
          reservation_job_execution: execution,
          site: site,
          date: date,
          status: :open
        ).order(:time_slot).pluck(:time_slot)
        write_camp_txt(date, site, slots)
      end
    end
  end

  def write_camp_txt(date, site, slots)
    return if Rails.env.production?

    if slots.empty?
      output = "#{date.strftime('%Y%m%d')} サイト#{site.site_no} 終日予約不可"
    else
      formatted_times = slots.map { |t| t.strftime('%-H:%M') }
      blocks = []
      current_block = []
      formatted_times.each_with_index do |time, idx|
        if current_block.empty?
          current_block << time
        else
          prev_time = Time.parse(formatted_times[idx - 1])
          curr_time = Time.parse(time)
          if (curr_time - prev_time) == 3600
            current_block << time
          else
            blocks << current_block
            current_block = [time]
          end
        end
      end
      blocks << current_block unless current_block.empty?
      ranges = blocks.map { |blk| "#{blk.first}〜#{blk.last}" }
      output = "#{date.strftime('%Y%m%d')} サイト#{site.site_no} #{ranges.join(', ')} 予約可"
    end
    File.open(Rails.root.join('camp.txt'), 'a') { |f| f.puts output }
  end
end
