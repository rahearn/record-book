# Two of the record book's columns are Postgres arrays whose order carries
# meaning — a lineup slot's player positions read most-played first, and a
# season's roster slots are a list that repeats ("rb", "rb", "wr"...). Neither
# survives a set of checkboxes, so the admin forms edit them as a single
# comma-separated text box and hand the splitting back here.
module ListColumnParams
  extend ActiveSupport::Concern

  private

  # Idempotent: Inherited Resources memoizes the params it hands out, so the
  # same attributes may come back around already split.
  def split_list_column(attributes, name)
    value = attributes[name]
    attributes[name] = value.split(",").map(&:strip).compact_blank if value.is_a?(String)
    attributes
  end
end
