# The league tier a record belongs to: a single unified league before 2025,
# Premier/Challenger since.
module Tiered
  extend ActiveSupport::Concern

  included do
    enum :tier, { unified: 0, premier: 1, challenger: 2 }, default: :unified
  end
end
