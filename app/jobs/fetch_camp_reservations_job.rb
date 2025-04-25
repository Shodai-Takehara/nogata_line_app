# frozen_string_literal: true

class FetchCampReservationsJob < ApplicationJob
  queue_as :default

  BASE_URL = 'https://nogata-camp.info/reserve'.freeze

  def perform(start_date: Time.zone.today, end_date: Time.zone.today.next_month.end_of_month)
    agent = Mechanize.new
    agent.user_agent_alias = 'Windows Chrome'

    # キャンプ場特定（現状1つのみ）
    campground = Campground.find_by!(name: '直方キャンプ場')
    execution = ReservationJobExecution.create!(campground: campground, executed_at: Time.zone.now)

    (start_date..end_date).each do |date|
      fetch_and_save_slots(agent, campground, execution, date)
    end

    # 全日分のrange集計＆txt出力
    (start_date..end_date).each do |date|
      Site.where(campground: campground).order(:site_no).each do |site|
        slots = ReservationSlot.where(
          reservation_job_execution: execution,
          site: site,
          date: date,
          status: :open
        ).order(:time_slot).pluck(:time_slot)

        if slots.empty?
          output = "#{date.strftime('%Y%m%d')} サイト#{site.site_no} 終日予約不可"
        else
          formatted_times = slots.map { |t| t.strftime('%-H:%M') }
          blocks = []
          current_block = []

          formatted_times.each do |time|
            if current_block.empty?
              current_block << time
            elsif Time.parse(time) - Time.parse(current_block.last) == 3600
              current_block << time
            else
              blocks << current_block
              current_block = [ time ]
            end
          end
          blocks << current_block unless current_block.empty?
          ranges = blocks.map { |blk| "#{blk.first}〜#{blk.last}" }
          output = "#{date.strftime('%Y%m%d')} サイト#{site.site_no} #{ranges.join(', ')} 予約可"
        end

        File.open(Rails.root.join('camp.txt'), 'a') { |f| f.puts output }
      end
    end
  end

  private

  def fetch_and_save_slots(agent, campground, execution, target_date)
    params = { reserveDate: target_date.to_s, _: (Time.zone.now.to_f * 1000).to_i }
    page = agent.get("#{BASE_URL}/reserve-site", params)
    doc = Nokogiri::HTML(page.body)
    tbody = doc.at('table.calendar__site__table tbody')

    site_map = Site.where(campground: campground).index_by { |s| s.site_no }

    tbody.css('tr.calendar__time').each do |tr|
      # そのtrの最初のtdのdata-reservestartdatetimeから日付を取得
      first_td = tr.at('td')
      next unless first_td
      reserve_dt = first_td['data-reservestartdatetime']
      next unless reserve_dt
      date_str, _ = reserve_dt.split(' ')
      date = Date.parse(date_str)
      next unless date == target_date

      tr.css('td').each do |td|
        reserve_dt = td['data-reservestartdatetime']
        next unless reserve_dt
        _, time_str = reserve_dt.split(' ')
        site_no = td['data-siteid'].to_i
        site = site_map[site_no]
        next unless site

        time = td.text.strip
        next if time.empty? || time == '--:--'
        status = td['class']&.include?('calendar__time--open') ? :open : :close

        ReservationSlot.find_or_create_by!(
          reservation_job_execution: execution,
          site: site,
          date: date,
          time_slot: time_str
        ) do |slot|
          slot.status = status
        end
      end
    end
  end
end
