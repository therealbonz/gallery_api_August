class CreateReactions < ActiveRecord::Migration[6.1]
  def change
    create_table :reactions do |t|
      t.string :emoji, null: false
      t.references :photo, null: false, foreign_key: true
      t.references :user, foreign_key: true, null: true
      t.string :guest_id

      t.timestamps
    end
    add_index :reactions, [:photo_id, :user_id, :emoji], unique: true, where: 'user_id IS NOT NULL'
    add_index :reactions, [:photo_id, :guest_id, :emoji], unique: true, where: 'guest_id IS NOT NULL'
  end
end
