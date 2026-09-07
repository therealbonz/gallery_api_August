class User < ApplicationRecord
  has_secure_password

  has_many :photos, dependent: :destroy
  has_many :comments, dependent: :nullify
  has_many :reactions, dependent: :destroy

  validates :username, presence: true, uniqueness: { case_sensitive: false }, length: { minimum: 3, maximum: 30 }
  validates :email, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, allow_nil: true
end
