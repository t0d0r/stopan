# Settings of the whole service desk, kept in one row (specs/board.md).
class AppSetting < ApplicationRecord
  include RefreshesAdminPages

  validates :auto_postpone_days, numericality: { only_integer: true, in: 0..3650 }

  def self.current
    first || create!
  end
end
