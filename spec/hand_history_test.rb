# frozen_string_literal: true

require 'minitest/autorun'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'pstars'

class TestHandHistory < Minitest::Test
  def setup
    file_path = File.join(File.dirname(__FILE__), 'fixtures/544010396.log')
    @h = PStars::HandHistory.new(file_path)
  end

  def test_parse
    @h.parse
  end

  def test_vpip
    @h.calculate_stats('malik_msk')
  end
end
