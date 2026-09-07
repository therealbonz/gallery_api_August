class AddMediaTypeToPhotos < ActiveRecord::Migration[6.1]
  def change
    add_column :photos, :media_type, :string, default: 'image'
  end
end
