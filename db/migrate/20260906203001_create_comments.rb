class CreateComments < ActiveRecord::Migration[6.1]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.references :photo, null: false, foreign_key: true
      t.references :user, foreign_key: true, null: true
      t.string :guest_name

      t.timestamps
    end
  end
end
