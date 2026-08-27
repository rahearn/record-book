require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "the nav moves between the record book's pages" do
    visit root_path
    assert_selector "h2", text: "All-time by owner"

    click_on "Owners"
    assert_selector "h1", text: "Alice Anders"

    click_on "Seasons"
    assert_selector "h1", text: "2024"

    click_on "League"
    assert_selector "h2", text: "All-time by owner"
  end

  test "the owner select navigates without a submit button" do
    visit owners_path
    assert_selector "h1", text: "Alice Anders"

    select "Bob Barker — Barker Bandits", from: "owner_id"

    assert_selector "h1", text: "Bob Barker"
    assert_current_path owners_path(id: owners(:bob).id)
  end
end
