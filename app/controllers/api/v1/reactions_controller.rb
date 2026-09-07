module Api
  module V1
    class ReactionsController < ApplicationController
      before_action :set_photo

      # POST /api/v1/photos/:photo_id/reactions
      def toggle
        emoji = params[:emoji].to_s.strip
        unless Reaction::ALLOWED_EMOJIS.include?(emoji)
          render json: { error: "Invalid emoji. Allowed: #{Reaction::ALLOWED_EMOJIS.join(' ')}" }, status: :unprocessable_entity
          return
        end

        guest_id = params[:guest_id].presence || request.remote_ip

        reaction = if current_user
                     @photo.reactions.find_by(user_id: current_user.id, emoji: emoji)
                   else
                     @photo.reactions.find_by(guest_id: guest_id, emoji: emoji)
                   end

        if reaction
          reaction.destroy
          toggled = false
        else
          @photo.reactions.create!(
            user: current_user,
            guest_id: current_user ? nil : guest_id,
            emoji: emoji
          )
          toggled = true
        end

        render json: {
          toggled: toggled,
          emoji: emoji,
          reactions_summary: @photo.reactions_summary,
          likes_count: @photo.likes_count
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def set_photo
        @photo = Photo.find(params[:photo_id] || params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Photo not found' }, status: :not_found
      end
    end
  end
end
