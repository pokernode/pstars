# frozen_string_literal: true

require 'json'

module PStars
  class HandHistory
    class Game
      FIELDS = %i[
        gid
        table_name
        button
        seats
        stacks
        players
        sb
        bb
        bets
        known_cards
        winners
        went_to_showdown
        won_at_showdown
        lost_at_showdown
        folded_before_flop
        pot
        rake
        flop
        turn
        river
        tournament
        table
        dealt_at
      ].freeze

      attr_reader :players, :data

      def initialize(data)
        @data = data
        positions = @data.seats.keys.sort
        @players = []
        return if positions.empty?

        dealer_index = positions.index(@data.button) || 0
        cutoff = (dealer_index + 3) % positions.size
        normalized = positions.rotate(cutoff)
        @players = normalized.map { |seat| @data.seats[seat] }
      end

      def gid
        @data.gid
      end

      def to_json(*_args)
        JSON.pretty_generate(data.to_h)
      end

      def preflop_action
        @data.bets[:preflop]
      end

      def in_play?(player)
        preflop_action.key?(seat_index(player))
      end

      def raised?(player)
        preflop_raisers.include?(player)
      end

      def open_raiser?(player)
        preflop_raisers.first == player
      end

      def last_raiser?(player)
        preflop_raisers.last == player
      end

      def preflop_raisers
        @players.select do |player|
          next unless in_play?(player)

          move = preflop_action[seat_index(player)].first
          move.is_a?(Hash) && (move.key?(:raise) || move.key?(:bet))
        end
      end

      def voluntary_puts
        @players.select do |player|
          next unless in_play?(player)

          move = preflop_action[seat_index(player)].first
          next if player == @data.bb && move == :check

          move != :fold
        end
      end

      def went_to_showdown?(player)
        @data.went_to_showdown.include?(player)
      end

      def won_at_showdown?(player)
        @data.won_at_showdown.include?(seat_index(player))
      end

      def won?(player)
        @data.winners.key?(seat_index(player))
      end

      def openraiser
        preflop_raisers[0]
      end

      def second_raiser
        preflop_raisers[1]
      end

      def three_bet_pot?
        openraiser && second_raiser
      end

      def folded_preflop?(player)
        actions = preflop_action[seat_index(player)]
        actions && actions.last == :fold
      end

      def seen_flop?(player)
        !folded_preflop?(player)
      end

      def cold_call?(player)
        preflop_action.fetch(seat_index(player), []).all? { |action| action.is_a?(Hash) && action.key?(:call) }
      end

      def aggression(player)
        bet_count = 0
        call_count = 0

        @data.bets.each_pair do |_street, bets|
          next unless bets[seat_index(player)]

          bets[seat_index(player)].each do |bet|
            bet_count += 1 if bet.is_a?(Hash) && (bet.key?(:raise) || bet.key?(:bet))
            call_count += 1 if bet.is_a?(Hash) && bet.key?(:call)
          end
        end

        { total: [bet_count, call_count] }
      end

      def folded_to_steal
        [].tap do |folds|
          if openraiser
            folds << @data.sb if folded_preflop?(@data.sb)
            folds << @data.bb if folded_preflop?(@data.bb)
          end
        end
      end

      def seat_index(player)
        @data.seats.key(player)
      end
    end
  end
end
