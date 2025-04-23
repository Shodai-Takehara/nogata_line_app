# frozen_string_literal: true

require 'mechanize'
require 'nokogiri'

class FetchCampReservationsJob < ApplicationJob
  queue_as :default

  BASE_URL = 'https://nogata-camp.info/reserve'.freeze

  # 引数で日付レンジを渡せるようにオプション化
  # perform() の引数を省略すると「今日〜来月末」を自動取得します
  def perform(start_date: Date.today, end_date: Date.today.next_month.end_of_month)
    agent = Mechanize.new
    agent.user_agent_alias = 'Windows Chrome'

    # 最初にトップページにアクセスして CSRF／JSESSIONID を取得
    agent.get("#{BASE_URL}/")

    (start_date..end_date).each do |date|
      fetch_for_date(agent, date)
    end
  end

  private

  def fetch_for_date(agent, date)
    # タイムスタンプ付きで reserve-site ページを取得
    params = { reserveDate: date.to_s, _: (Time.now.to_f * 1000).to_i }
    page   = agent.get("#{BASE_URL}/reserve-site", params)
    doc    = Nokogiri::HTML(page.body)

    # 日付ヘッダー以降の最初の <tr class="calendar__time">群を切り出し
    tbody = doc.at('table.calendar__site__table tbody')
    rows = tbody.css('tr.calendar__time')

    Rails.logger.debug "Found #{rows.size} time rows for #{date}"

    # その日が予約可能かどうかをチェック
    has_any_open = false
    rows.each do |row|
      row.css('td').each do |td|
        if td['class']&.include?('calendar__time--open')
          has_any_open = true
          break
        end
      end
      break if has_any_open
    end

    unless has_any_open
      Rails.logger.info "#{date.strftime('%Y%m%d')} 全サイト予約不可"
      File.open(Rails.root.join('camp.txt'), 'a') do |f|
        f.puts "#{date.strftime('%Y%m%d')} 全サイト予約不可"
      end
      return
    end

    # サイトごとに open セルだけ集める
    site_times = Hash.new { |h, k| h[k] = [] }
    rows.each do |tr|
      tr.css('td').each_with_index do |td, index|
        next unless td['class']&.include?('calendar__time--open')
        sid = td['data-siteid'].to_i
        time = td.text.strip
        site_times[sid] << time
      end
    end

    Rails.logger.debug "Found available times for sites: #{site_times.keys.join(', ')}"

    # 各サイトの予約可否・時間帯をまとめてログ出力
    (1..30).each do |sid|
      times = site_times[sid]
      next if times.empty?  # 予約不可の場合はスキップ

      # 時間を整形してソート
      formatted_times = times.map { |t| t.sub(/^0/, '') }.uniq.sort_by { |t| Time.parse(t) }

      # 連続時間帯をまとめる
      blocks = []
      current_block = [ formatted_times.first ]

      formatted_times[1..-1].each do |time|
        if Time.parse(time) - Time.parse(current_block.last) == 3600
          current_block << time
        else
          blocks << current_block
          current_block = [ time ]
        end
      end
      blocks << current_block unless current_block.empty?

      # 12:00〜21:00の連続した予約可能時間があるかチェック
      full_day_block = blocks.find do |block|
        block.first == '12:00' && block.last == '21:00' &&
        block.size == 10  # 12:00から21:00まで1時間おきに10個の時間帯がある
      end

      ranges = if full_day_block
        [ '12:00〜21:00' ]  # 12:00〜21:00の場合はこれのみ出力
      else
        blocks.map { |blk| "#{blk.first}〜#{blk.last}" }
      end

      output = "サイト#{sid} #{ranges.join(', ')} 予約可"

      Rails.logger.info "#{date.strftime('%Y%m%d')} #{output}"
      File.open(Rails.root.join('camp.txt'), 'a') do |f|
        f.puts "#{date.strftime('%Y%m%d')} #{output}"
      end
    end
  end
end
