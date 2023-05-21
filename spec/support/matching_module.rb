module MatchingModule
  def matching(other_customer)
    visit public_customer_path(other_customer)
    find_all('a')[6].click
    find_all('a')[1].click
    login(other_customer)
    visit public_customer_path(customer)
    find_all('a')[6].click
  end
end