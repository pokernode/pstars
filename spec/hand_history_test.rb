# frozen_string_literal: true

require 'minitest/autorun'

class TestHandHistory < Minitest::Test
  def setup
    @h = HandHistory.new(File.join(File.dirname(__FILE__), '/fixtures'))
  end

  def test_parse
    @h.parse('h1.txt')
  end

  def test_vpip
    @h.calculate_stats('hh.txt', 'malik_msk')
  end
end
