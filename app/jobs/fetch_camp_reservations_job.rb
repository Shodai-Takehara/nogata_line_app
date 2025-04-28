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

  ##
  # HTMLから予約スロット情報を抽出し、ReservationSlotを生成する
  #
  # @param doc [Nokogiri::HTML::Document] パース済みHTMLドキュメント
  # @param execution [ReservationJobExecution] ジョブ実行レコード
  # @param sites [Array<Site>] サイト一覧
  # @param from_date [Date] 取得開始日
  # @param to_date [Date] 取得終了日
  # @param end_date [Date] 取得最終日
  # @return [Hash{Date=>Hash{Integer=>Array<Time>}}] 日付・サイトごとの空き時刻マップ
  def parse_and_save_slots(doc, execution, sites, from_date, to_date, end_date)
    now      = Time.zone.now
    tds      = doc.css('tbody tr.calendar__time').css('td')
    slot_map = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
    tds.each do |td|
      site_no = td['data-siteid']&.to_i
      next unless site_no

      site = sites.find { |s| s.site_no == site_no }
      next unless site

      datetime_str = td['data-reservestartdatetime']
      next unless datetime_str

      # 例: "2025/04/26 07:00"
      if datetime_str =~ /(\d{4})\/(\d{2})\/(\d{2}) (\d{2}):(\d{2})/
        y, m, d, h, min = $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i
        date = Date.new(y, m, d) rescue nil
        time_slot = Time.parse("2000-01-01 #{h}:#{min}")
      else
        next
      end
      next unless date_in_range?(date, from_date, to_date, end_date)

      # 時間外判定
      status =
        if date == Time.zone.today && Time.zone.local(now.year, now.month, now.day, h, min) < now
          :out_of_hours
        else
          td['class']&.include?('calendar__time--open') ? :open : :close
        end

      execution.reservation_slots.find_or_create_by!(
        site: site,
        date: date,
        time_slot: time_slot
      ) { |slot| slot.status = status }
      slot_map[date][site_no] << time_slot if status == :open
    end

    slot_map
  end

  ##
  # camp.txtへの出力を行う
  #
  # @param slot_map [Hash{Date=>Hash{Integer=>Array<Time>}}] 日付・サイトごとの空き時刻マップ
  # @param sites [Array<Site>] サイト一覧
  def output_camp_txt(slot_map, sites)
    slot_map.each do |date, site_hash|
      site_hash.sort_by { |site_no, _| site_no }.each do |site_no, slots|
        sorted_slots = slots.sort_by { |t| t.strftime('%H:%M:%S') }
        site = sites.find { |s| s.site_no == site_no }
        write_camp_txt(date, site, sorted_slots)
      end
    end
  end

  ##
  # 日付範囲判定
  #
  # @param date [Date]
  # @param from_date [Date]
  # @param to_date [Date]
  # @param end_date [Date]
  # @return [Boolean]
  def date_in_range?(date, from_date, to_date, end_date)
    date && date >= from_date && date <= to_date && date <= end_date
  end

  ##
  # camp.txtへの1行出力
  #
  # @param date [Date]
  # @param site [Site]
  # @param slots [Array<Time>]
  def write_camp_txt(date, site, slots)
    if slots.empty?
      output = "#{date.strftime('%Y%m%d')} サイト#{site.site_no} 終日予約不可"
    else
      blocks          = []
      current_block   = []
      formatted_times = slots.map { |t| t.strftime('%-H:%M') }
      formatted_times.each_with_index do |time, idx|
        if current_block.empty?
          current_block << time
        else
          prev_time = Time.zone.parse(formatted_times[idx - 1])
          curr_time = Time.zone.parse(time)
          if (curr_time - prev_time) == 3600
            current_block << time
          else
            blocks << current_block
            current_block = [ time ]
          end
        end
      end
      blocks << current_block unless current_block.empty?
      ranges = blocks.map { |blk| "#{blk.first}〜#{blk.last}" }
      output = "#{date.strftime('%Y%m%d')} サイト#{site.site_no} #{ranges.join(', ')} 予約可"
    end
    File.open(Rails.root.join('camp.txt'), 'a') { |f| f.puts output }
  end

  ##
  # メインのスロット取得・保存・出力処理
  #
  # @param agent [Mechanize]
  # @param campground [Campground]
  # @param execution [ReservationJobExecution]
  # @param from_date [Date]
  # @param to_date [Date]
  # @param sites [Array<Site>]
  # @param end_date [Date]
  def fetch_and_save_slots(agent, campground, execution, from_date, to_date, sites, end_date)
    params   = { reserveDate: from_date.to_s, _: (Time.now.to_f * 1000).to_i }
    page     = agent.get("#{BASE_URL}/reserve-site/selectDate", params)
    json     = JSON.parse(page.body)
    html     = json.dig('data', 'reflash')
    doc      = Nokogiri::HTML(html)
    slot_map = parse_and_save_slots(doc, execution, sites, from_date, to_date, end_date)
    output_camp_txt(slot_map, sites) if Rails.env.development?
  end

  ##
  # 日付を抽出する
  #
  # @param th [Nokogiri::XML::Element]
  # @return [Date, nil]
  def extract_date_from_th(th)
    return nil unless th

    year = th.at('.year')&.text&.strip =~ /(\d{4})年/ ? $1.to_i : Time.zone.today.year
    if th.at('.month')&.text&.strip =~ /(\d{1,2})月(\d{1,2})日/
      month = $1.to_i
      day = $2.to_i
      Date.new(year, month, day) rescue nil
    end
  end
end
