ActiveRecord::Schema.define do
  # The AR Schema doesn't set the sequence option for the
  # companies table, but uses a custom sequence name.
  create_sequence "COMPANIES_NONSTD_SEQ"

  create_table :foos, force: true do |t|
    t.integer :v
  end

  create_table :bars, force: true do |t|
    t.string :v1
    t.string :v2
    t.string :v3
  end
end
