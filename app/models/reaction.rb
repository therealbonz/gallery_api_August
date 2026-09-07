class Reaction < ApplicationRecord
  ALLOWED_EMOJIS = ['🔥', '❤️', '😍', '🚀', '👏', '😂'].freeze

  belongs_to :photo
  belongs_to :user, optional: true

  validates :emoji, presence: true, inclusion: { in: ALLOWED_EMOJIS }
end
