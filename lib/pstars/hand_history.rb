# frozen_string_literal: true

require 'pathname'

module PStars
  class HandHistory
    autoload :Parser, 'pstars/hand_history/parser'
    autoload :Game, 'pstars/hand_history/game'

    def initialize(file_path)
      @file_path = Pathname(file_path)
    end

    def parse(file_path = @file_path)
      with_parser(file_path) do |data|
        Game.new(data)
      end
    end

    def known_cards(player, file_path = @file_path)
      with_parser(file_path) do |data|
        seat = data.seats.key(player)
        next unless seat

        hole_cards = data.known_cards[seat]
        winnings = data.winners[seat]
        puts "#{hole_cards}\t\t#{winnings}" if hole_cards && winnings
      end
    end

    def calculate_stats(player, file_path = @file_path)
      totals = build_totals

      with_parser(file_path) do |data|
        game = Game.new(data)
        next unless game.in_play?(player)

        update_totals(totals, game, player)
      end

      display_totals(totals)
    end

    private

    def with_parser(file_path)
      parser = Parser.new(Pathname(file_path))
      parser.parse do |data|
        yield data
      end
    end

    def build_totals
      {
        total: 0,
        put: 0,
        pfr: 0,
        wtsd: 0,
        wsd: 0,
        seen_flop: 0,
        won: 0,
        cc: 0,
        aggression: { total: [0, 0] }
      }
    end

    def update_totals(totals, game, player)
      totals[:put] += 1 if game.voluntary_puts.include?(player)
      totals[:pfr] += 1 if game.preflop_raisers.include?(player)
      totals[:wtsd] += 1 if game.went_to_showdown?(player)
      totals[:wsd] += 1 if game.won_at_showdown?(player)
      totals[:seen_flop] += 1 if game.seen_flop?(player)
      totals[:won] += 1 if game.won?(player)
      totals[:cc] += 1 if game.cold_call?(player)

      aggression = game.aggression(player)
      aggression[:total].each_with_index do |value, index|
        totals[:aggression][:total][index] += value
      end

      totals[:total] += 1
    end

    def display_totals(totals)
      aggression_total = totals[:aggression][:total]
      aggression_factor = if aggression_total[1].zero?
                            0.0
                          else
                            Rational(*aggression_total).to_f
                          end

      output = [
        "VP$IP #{format('%.2f%%', percentage(totals[:put], totals[:total]))}",
        "PFR #{format('%.2f%%', percentage(totals[:pfr], totals[:total]))}",
        "Af #{format('%.2f', aggression_factor)}",
        "CC #{format('%.2f%%', percentage(totals[:cc], totals[:seen_flop]))}",
        "WTSD #{format('%.2f%%', percentage(totals[:wtsd], totals[:seen_flop]))}",
        "WSD #{format('%.2f%%', percentage(totals[:wsd], totals[:wtsd]))}",
        "H #{totals[:total]}",
        "W #{format('%.2f%%', percentage(totals[:won], totals[:total]))}",
        "WWSD #{format('%.2f%%', percentage(totals[:won] - totals[:wsd], totals[:total]))}"
      ].join("\t")

      puts output
    end

    def percentage(part, whole)
      return 0 if whole.zero?

      part.to_f / whole * 100
    end
  end
end
