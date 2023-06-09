module MatchingModule
  def matching(other_customer)
    visit public_customer_path(other_customer)
    find_all('a')[10].click
    find_all('a')[5].click
    login(other_customer)
    visit public_customer_path(customer)
    find_all('a')[10].click
  end
end