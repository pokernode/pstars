# frozen_string_literal: true

require 'date'

module PStars
  class HandHistory
    GameState = Struct.new(
      :gid,
      :table_name,
      :button,
      :seats,
      :stacks,
      :players,
      :sb,
      :bb,
      :bets,
      :known_cards,
      :winners,
      :went_to_showdown,
      :won_at_showdown,
      :lost_at_showdown,
      :folded_before_flop,
      :pot,
      :rake,
      :flop,
      :turn,
      :river,
      :tournament,
      :table,
      :dealt_at,
      keyword_init: true
    )

    class Parser
      def initialize(file_path)
        @file_path = file_path
      end

      def parse
        File.open(@file_path, 'r') do |file|
          reset

          file.each_line do |line|
            line.chomp!

            if line =~ /PokerStars Game/
              yield @game if block_given? && @game
              build_new_game(line)
              @state = :headers
              next
            end

            process_line(line)
          end

          yield @game if @game && block_given?
        end
      end

      private

      def reset
        @game = nil
        @state = nil
      end

      def process_line(line)
        case line
        when /said/
          nil
        when /\*\*\* (.*) \*\*\*/
          update_street(::Regexp.last_match(1))
        else
          process_content(line)
        end
      end

      def build_new_game(line)
        @game = GameState.new(
          seats: {},
          stacks: {},
          players: [],
          winners: {},
          went_to_showdown: [],
          won_at_showdown: [],
          lost_at_showdown: [],
          folded_before_flop: [],
          known_cards: {},
          bets: { preflop: {}, flop: {}, turn: {}, river: {} }
        )

        _game_header, details = line.split(/:\s+/, 2)
        line =~ /#(\d+)/
        @game.gid = ::Regexp.last_match(1).to_i

        parse_game_details(details)
      end

      def parse_game_details(details)
        if details =~ /Tournament #(\d+)/
          @game.tournament = { id: ::Regexp.last_match(1).to_i }
        else
          table, action = details.split(/\s+-\s+/, 2)
          table =~ /(.*) \((.*?)\)/
          @game.table = { type: ::Regexp.last_match(1), limits: ::Regexp.last_match(2).split('/').map(&:to_i) }
          action =~ /\[(.*?)\]/
          @game.dealt_at = DateTime.strptime(::Regexp.last_match(1), '%Y/%m/%d %H:%M:%S ET')
        end
      end

      def process_content(line)
        case @state
        when :headers
          parse_headers(line)
        when :summary
          parse_summary(line)
        when :showdown
          parse_showdown(line)
        when :preflop
          parse_preflop(line)
        else
          parse_street(line)
        end
      end

      def update_street(header)
        case header
        when 'FLOP'
          header =~ /\[(.*)\]/
          @game.flop = ::Regexp.last_match(1)
          @state = :flop
        when 'TURN'
          header =~ /\[([^\[]*?)\]$/
          @game.turn = ::Regexp.last_match(1)
          @state = :turn
        when 'RIVER'
          header =~ /\[([^\[]*?)\]$/
          @game.river = ::Regexp.last_match(1)
          @state = :river
        when 'SHOW DOWN'
          @state = :showdown
        when 'HOLE CARDS'
          @state = :preflop
        when 'SUMMARY'
          @state = :summary
        end
      end

      def parse_preflop(line)
        if line.start_with?('Dealt') && line =~ /Dealt to (.*?) \[(.*)\]/
          seat = player_index(::Regexp.last_match(1))
          @game.known_cards[seat] = ::Regexp.last_match(2) if seat
        end

        parse_street(line)
      end

      def parse_action(action)
        case action
        when /calls \$?([\d.]+)/
          { call: ::Regexp.last_match(1).to_f }
        when /bets \$?([\d.]+)/
          { bet: ::Regexp.last_match(1).to_f }
        when /raises \$?([\d.]+) to \$?([\d.]+)/
          { raise: [::Regexp.last_match(1).to_f, ::Regexp.last_match(2).to_f] }
        when /small blind/
          :sb
        when /big blind/
          :bb
        when /folds/
          :fold
        when /checks/
          :check
        end
      end

      def parse_headers(line)
        if line.start_with?('Table')
          line =~ /Table (.*?) Seat #(\d+) is the button/
          @game.table_name = ::Regexp.last_match(1)
          @game.button = ::Regexp.last_match(2).to_i
        elsif line.start_with?('Seat')
          line =~ /Seat (\d+): (.*?) \(\$?([\d.]+) in chips\)/
          seat = ::Regexp.last_match(1).to_i
          name = ::Regexp.last_match(2)
          @game.seats[seat] = name
          @game.stacks[seat] = ::Regexp.last_match(3).to_f
          @game.players << name
        elsif line.include?(':')
          player, action = line.split(/:\s+/, 2)
          assign_blinds(player, action)
        end
      end

      def assign_blinds(player, action)
        if action.start_with?('posts small blind')
          @game.sb = player
        elsif action.start_with?('posts big blind')
          @game.bb = player
        end
      end

      def parse_summary(line)
        if line =~ /Total pot \$?(\d+) | Rake \$?(\d+)/
          @game.pot = ::Regexp.last_match(1).to_i
          @game.rake = ::Regexp.last_match(2).to_i
        end

        return unless line.start_with?('Seat')

        line.gsub!(/\((small blind|big blind|button)\)\s+/, '')
        line =~ /^Seat \d+: (.*?) (showed|folded|mucked|collected)/
        seat = player_index(::Regexp.last_match(1))
        return unless seat

        case line
        when /won \(\$?([\d.]+?)\)/
          @game.winners[seat] = ::Regexp.last_match(1).to_f
          @game.won_at_showdown << seat
          @game.known_cards[seat] = ::Regexp.last_match(1) if line =~ /showed \[(.+?)\]/
        when /collected \(\$?([\d.]+?)\)/
          @game.winners[seat] = ::Regexp.last_match(1).to_f
        when /lost|mucked/
          @game.lost_at_showdown << seat
          @game.known_cards[seat] = ::Regexp.last_match(1) if line =~ /mucked \[(.+?)\]/
        when /folded before flop/
          @game.folded_before_flop << seat
        end
      end

      def parse_showdown(line)
        return unless line =~ /^(.*?):/

        @game.went_to_showdown << ::Regexp.last_match(1)
      end

      def parse_street(line)
        return unless line.include?(':')

        player, action = line.split(/:\s+/, 2)
        seat = player_index(player)
        return unless seat

        if action.start_with?('shows')
          action =~ /\[(.*)\]/
          @game.known_cards[seat] = ::Regexp.last_match(1)
        else
          @game.bets[@state][seat] ||= []
          parsed_action = parse_action(action)
          @game.bets[@state][seat] << parsed_action if parsed_action
        end
      end

      def player_index(name)
        @game&.seats&.key(name)
      end
    end
  end
end
