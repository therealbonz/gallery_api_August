class Comment < ApplicationRecord
  belongs_to :photo
  belongs_to :user, optional: true

  validates :body, presence: true, length: { minimum: 1, maximum: 500 }

  def author_name
    user&.username || guest_name.presence || 'Guest'
  end

  def as_json(options = {})
    super(options.merge(
      methods: [:author_name]
    ))
  end
end
