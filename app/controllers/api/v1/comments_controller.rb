module Api
  module V1
    class CommentsController < ApplicationController
      before_action :set_photo, only: [:index, :create]
      before_action :set_comment, only: [:destroy]

      # GET /api/v1/photos/:photo_id/comments
      def index
        @comments = @photo.comments.includes(:user).order(created_at: :asc)
        render json: @comments
      end

      # POST /api/v1/photos/:photo_id/comments
      def create
        @comment = @photo.comments.build(comment_params)
        if current_user
          @comment.user = current_user
        else
          @comment.guest_name = comment_params[:guest_name].presence || params[:guest_name].presence || 'Guest'
        end

        if @comment.save
          render json: @comment, status: :created
        else
          render json: { errors: @comment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/comments/:id
      def destroy
        if current_user && (@comment.user_id == current_user.id || @comment.photo.user_id == current_user.id)
          @comment.destroy
          render json: { message: 'Comment deleted' }, status: :ok
        else
          render json: { error: 'Not authorized to delete this comment' }, status: :forbidden
        end
      end

      private

      def set_photo
        @photo = Photo.find(params[:photo_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Photo not found' }, status: :not_found
      end

      def set_comment
        @comment = Comment.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Comment not found' }, status: :not_found
      end

      def comment_params
        params.require(:comment).permit(:body, :guest_name)
      end
    end
  end
end
