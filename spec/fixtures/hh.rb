# frozen_string_literal: true

f = File.open('544010396.log')
won = nil
current = ''
while (line = f.gets)
  if line.start_with?('PokerStars Game')
    puts current if won
    current = ''
    won = false
  elsif line =~ /malik_msk collected (\d+) from pot/
    won = true if Regexp.last_match(1).to_i > 1000
  end
  current += line
end
