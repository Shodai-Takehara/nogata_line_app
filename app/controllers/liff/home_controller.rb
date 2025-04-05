module Liff
  class HomeController < ApplicationController
    layout 'liff/application'

    def index
      # LIFFの初期化処理など
      @liff_id = ENV.fetch('LIFF_CHANNEL_ID', nil)
      @dev_mode = true # 開発モードを強制的に有効化
    end
  end
end
