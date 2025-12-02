# frozen_string_literal: true

require 'minitest/autorun'

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'pstars'

class TestHandHistory < Minitest::Test
  def setup
    @h = Pstars::HandHistory.new(File.join(File.dirname(__FILE__), '/fixtures'))
  end

  def test_parse
    @h.parse('544010396.log')
  end

  def test_vpip
    @h.calculate_stats('544010396.log', 'malik_msk')
  end
end
