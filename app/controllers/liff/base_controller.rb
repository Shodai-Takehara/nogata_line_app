class Liff::BaseController < ApplicationController
  layout "liff/application"
  before_action :set_liff_variables

  private

  def set_liff_variables
    @liff_id = ENV.fetch("LIFF_CHANNEL_ID", nil)
    @dev_mode = Rails.env.development? # 開発環境の場合のみ開発モードを有効化
    @current_user = current_user # 現在のユーザー情報をビューに渡す
  end
end
