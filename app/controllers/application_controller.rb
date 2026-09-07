class ApplicationController < ActionController::API
  SECRET_KEY = Rails.application.secret_key_base || 'gallery_secret_key_123'

  def encode_token(payload)
    payload[:exp] = 30.days.from_now.to_i
    JWT.encode(payload, SECRET_KEY)
  end

  def decoded_token
    header = request.headers['Authorization']
    if header
      token = header.split(' ')[1]
      begin
        JWT.decode(token, SECRET_KEY, true, algorithm: 'HS256')
      rescue JWT::DecodeError
        nil
      end
    end
  end

  def current_user
    if decoded_token
      user_id = decoded_token[0]['user_id']
      @current_user ||= User.find_by(id: user_id)
    end
  end

  def authenticate_user!
    render json: { error: 'Please log in to continue' }, status: :unauthorized unless current_user
  end
end
