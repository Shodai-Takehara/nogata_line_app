class User < ApplicationRecord
  validates :line_user_id, presence: true, uniqueness: true

  # LINEプロフィールからユーザーを検索または作成
  def self.find_or_create_from_line_profile(profile)
    Rails.logger.info "プロフィール情報: #{profile.inspect}"

    user_id = profile["userId"] || profile[:userId]

    # ユーザーIDが指定されていない場合はエラー
    unless user_id.present?
      Rails.logger.error "ユーザーID (userId) が指定されていません"
      raise "ユーザーIDが指定されていません"
    end

    # 既存ユーザーを検索
    user = find_by(line_user_id: user_id)

    # 新規ユーザーの場合は作成
    unless user
      display_name = profile["displayName"] || profile[:displayName] || "名称未設定"
      picture_url = profile["pictureUrl"] || profile[:pictureUrl]
      status_message = profile["statusMessage"] || profile[:statusMessage]

      user = new(
        line_user_id: user_id,
        name: display_name,
        profile_image_url: picture_url,
        status_message: status_message
      )
      user.save!
      Rails.logger.info "新規ユーザーを作成しました: #{user.id}"
    else
      Rails.logger.info "既存ユーザーを見つけました: #{user.id}"
    end

    # ログイン時間の更新と既存プロフィール情報の更新
    display_name = profile["displayName"] || profile[:displayName]
    picture_url = profile["pictureUrl"] || profile[:pictureUrl]
    status_message = profile["statusMessage"] || profile[:statusMessage]

    user.update(
      last_login_at: Time.current,
      name: display_name || user.name, # 新しい値がない場合は既存の値を保持
      profile_image_url: picture_url || user.profile_image_url,
      status_message: status_message || user.status_message
    )

    user
  end
end
