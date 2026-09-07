module Api
  module V1
    class SessionsController < ApplicationController
      def create
        user = User.find_by('LOWER(email) = ?', params[:email].to_s.downcase)

        if user&.authenticate(params[:password])
          token = encode_token(user_id: user.id)
          render json: {
            token: token,
            user: { id: user.id, username: user.username, email: user.email }
          }, status: :ok
        else
          render json: { error: 'Invalid email or password' }, status: :unauthorized
        end
      end

      def me
        if current_user
          render json: {
            user: { id: current_user.id, username: current_user.username, email: current_user.email }
          }, status: :ok
        else
          render json: { error: 'Not authenticated' }, status: :unauthorized
        end
      end
    end
  end
end
