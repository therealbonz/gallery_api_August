class Photo < ApplicationRecord
  belongs_to :user, optional: true
  has_one_attached :image

  has_many :comments, -> { order(created_at: :asc) }, dependent: :destroy
  has_many :reactions, dependent: :destroy

  validates :title, presence: true
  validate :image_attached

  before_save :detect_media_type

  def image_url
    return nil unless image.attached?
    "/api/v1/photos/#{id}/image"
  end

  def reactions_summary
    reactions.group(:emoji).count
  end

  def likes_count
    reactions.where(emoji: ['❤️', '🔥']).count
  end

  def as_json(options = {})
    super(options.merge(
      include: {
        user: { only: [:id, :username] },
        comments: {
          include: { user: { only: [:id, :username] } },
          methods: [:author_name]
        }
      },
      methods: [:image_url, :reactions_summary, :likes_count]
    ))
  end

  private

  def detect_media_type
    if image.attached? && image.content_type.to_s.start_with?('video')
      self.media_type = 'video'
    else
      self.media_type = 'image'
    end
  end

  def image_attached
    errors.add(:image, 'must be attached') unless image.attached?
  end
end
