class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ], if: -> { request.format.json? }

  # LINEログイン後のコールバック処理
  def create
    # リクエストのフォーマットに応じてパラメータを取得
    profile_params =
      if request.format.json?
        params.require(:line_profile).permit(:userId, :displayName, :pictureUrl, :statusMessage)
      else
        line_user_params
      end

    # IDトークンからユーザー情報を取得し、ユーザーを作成または更新
    @user = User.find_or_create_from_line_profile(profile_params)

    # セッションにユーザーIDを保存
    session[:user_id] = @user.id

    respond_to do |format|
      format.html { redirect_to liff_root_path, notice: "ログインしました" }
      format.json { render json: { status: "success", user: @user, redirect: liff_root_path } }
    end
  rescue => e
    Rails.logger.error "ログインエラー: #{e.message}"
    respond_to do |format|
      format.html { redirect_to liff_root_path, alert: "ログインに失敗しました" }
      format.json { render json: { status: "error", message: e.message }, status: :unprocessable_entity }
    end
  end

  # ログアウト処理
  def destroy
    session.delete(:user_id)

    respond_to do |format|
      format.html { redirect_to liff_root_path, notice: "ログアウトしました" }
      format.json { render json: { status: "success", redirect: liff_root_path } }
    end
  end

  private

  def line_user_params
    params.require(:line_profile).permit(:userId, :displayName, :pictureUrl, :statusMessage)
  end
end
