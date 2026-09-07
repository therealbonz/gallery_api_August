module Api
  module V1
    class PhotosController < ApplicationController
      before_action :set_photo, only: [:show, :destroy, :image]

      # GET /api/v1/photos
      def index
        @photos = Photo.with_attached_image
                       .includes(:user, comments: :user, reactions: [])
                       .order(created_at: :desc)
        render json: @photos
      end

      # GET /api/v1/photos/:id
      def show
        render json: @photo
      end

      # GET /api/v1/photos/:id/image
      def image
        if @photo.image.attached?
          send_data @photo.image.download,
                    filename: @photo.image.filename.to_s,
                    content_type: @photo.image.content_type,
                    disposition: 'inline'
        else
          render json: { error: 'Media file not found' }, status: :not_found
        end
      end

      # POST /api/v1/photos
      def create
        @photo = Photo.new(photo_params)
        @photo.user = current_user if current_user

        if @photo.save
          render json: @photo, status: :created
        else
          render json: { errors: @photo.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/photos/batch
      def create_batch
        files = params[:images] || params[:files]
        unless files.present? && files.is_a?(Array)
          render json: { error: 'Please provide an array of files' }, status: :unprocessable_entity
          return
        end

        saved_photos = []
        errors = []

        files.each_with_index do |file, idx|
          title = params[:titles]&.[](idx).presence || file.original_filename.sub(/\.[^.]+\z/, '').humanize
          desc = params[:descriptions]&.[](idx)

          photo = Photo.new(title: title, description: desc, image: file)
          photo.user = current_user if current_user

          if photo.save
            saved_photos << photo
          else
            errors << "#{file.original_filename}: #{photo.errors.full_messages.join(', ')}"
          end
        end

        render json: {
          photos: saved_photos,
          uploaded_count: saved_photos.length,
          errors: errors
        }, status: saved_photos.any? ? :created : :unprocessable_entity
      end

      # DELETE /api/v1/photos/:id
      def destroy
        if @photo.user_id.present? && (!current_user || @photo.user_id != current_user.id)
          render json: { error: 'You are not authorized to delete this photo' }, status: :forbidden
          return
        end

        @photo.destroy
        render json: { message: 'Photo deleted successfully' }, status: :ok
      end

      # GET /api/v1/download/apk
      def download_apk
        apk_path = Rails.root.join('public', 'My3DCube.apk')
        if File.exist?(apk_path)
          send_file apk_path,
                    filename: 'My3DCube.apk',
                    type: 'application/vnd.android.package-archive',
                    disposition: 'attachment'
        else
          render json: { error: 'APK file not found on server' }, status: :not_found
        end
      end

      # GET /api/v1/download/exe
      def download_exe
        exe_path = Rails.root.join('public', 'My3DCubeWallpaper.exe')
        if File.exist?(exe_path)
          send_file exe_path,
                    filename: 'My3DCubeWallpaper.exe',
                    type: 'application/vnd.microsoft.portable-executable',
                    disposition: 'attachment'
        else
          render json: { error: 'Windows executable file not found on server' }, status: :not_found
        end
      end

      private

      def set_photo
        @photo = Photo.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Photo not found' }, status: :not_found
      end

      def photo_params
        params.require(:photo).permit(:title, :description, :image)
      end
    end
  end
end
