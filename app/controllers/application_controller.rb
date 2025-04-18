class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  protect_from_forgery with: :exception

  helper_method :current_user, :logged_in?

  before_action :set_ngrok_headers

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def authenticate_user!
    unless logged_in?
      redirect_to liff_root_path, alert: "ログインが必要です"
    end
  end

  def set_ngrok_headers
    response.headers['ngrok-skip-browser-warning'] = 'true' if Rails.env.development?
  end
end
