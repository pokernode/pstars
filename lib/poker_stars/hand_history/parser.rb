# frozen_string_literal: true

require 'active_support/all'

module PokerStars
  module HandHistory
    class Parser
      def initialize(file)
        @file = file
        @game = nil
        @state = nil
      end

      def player_index(n)
        @game[:seats].index(n)
      end

      def parse_preflop(line)
        # hole cards
        if line.start_with?('Dealt')
          line =~ /Dealt to (.*?) \[(.*)\]/
          @game[:known_cards][player_index(::Regexp.last_match(1))] = ::Regexp.last_match(2)
        end
        parse_street(line)
      end

      def parse_action(a)
        return 'call' => ::Regexp.last_match(1).to_f if a =~ /calls \$?([\d.]+)/
        return 'bet' => ::Regexp.last_match(1).to_f if a =~ /bets \$?([\d.]+)/
        if a =~ /raises \$?([\d.]+) to \$?([\d.]+)/
          return 'raise' => [::Regexp.last_match(1).to_f, ::Regexp.last_match(2).to_f]
        end
        return 'sb' if a =~ /small bind/
        return 'bb' if a =~ /big bind/
        return 'fold' if a =~ /folds/

        'check' if a =~ /checks/
      end

      def parse_game(line)
        @game = {
          stacks: {},
          seats: {},
          players: [],
          winners: {},
          went_to_showdown: [],
          won_at_showdown: [],
          lost_at_showdown: [],
          folded_before_flop: [],
          known_cards: {},
          bets: { 'preflop' => {}, 'flop' => {}, 'turn' => {}, 'river' => {} }
        }
        g, i = line.split(/:\s+/, 2)
        g =~ /#(\d+)/
        @game[:gid] = ::Regexp.last_match(1).to_i

        @game[:table] = {}
        if i =~ /Tournament #(\d+)/
          @game[:tournament] = {
            id: ::Regexp.last_match(1).to_i
          }

        else
          t, a = i.split(/\s+-\s+/, 2)
          t =~ /(.*) \((.*?)\)/
          @game[:tbl] = { type: ::Regexp.last_match(1), limits: ::Regexp.last_match(2).split('/').map(&:to_i) }
          a =~ /\[(.*?)\]/
          @game[:dealt_at] = DateTime.strptime(::Regexp.last_match(1), '%Y/%m/%d %H:%M:%S ET')
        end
      end

      def parse_headers(line)
        # table information
        if line.start_with?('Table')

          line =~ /Table (.*?) Seat #(\d+) is the button/
          @game[:table]['name'] = ::Regexp.last_match(1)
          @game[:button] = ::Regexp.last_match(2).to_i

        # seats information
        elsif line.start_with?('Seat')

          line =~ /Seat (\d+): (.*?) \(\$?([\d.]+) in chips\)/
          @game[:seats][::Regexp.last_match(1)] = ::Regexp.last_match(2)
          @game[:stacks][player_index(::Regexp.last_match(2))] = ::Regexp.last_match(3).to_f
          @game[:players] << ::Regexp.last_match(2)

        elsif line.index(':')

          p, a = line.split(/:\s+/, 2)

          if a.start_with?('posts small blind')
            @game[:sb] = p
          elsif a.start_with?('posts big blind')
            @game[:bb] = p
          end

        end
      end

      def parse_summary(line)
        if line =~ /Total pot \$?(\d+) | Rake \$?(\d+)/
          @game[:pot] = ::Regexp.last_match(1).to_i
          @game[:rake] = ::Regexp.last_match(2).to_i
        end

        return unless line.start_with?('Seat')

        line.gsub!(/\((small blind|big blind|button)\)\s+/, '')
        line =~ /^Seat \d+: (.*?) (showed|folded|mucked|collected)/
        p = player_index(::Regexp.last_match(1))

        case line
        when /won \(\$?([\d.]+?)\)/
          @game[:winners][p] = ::Regexp.last_match(1).to_f
          @game[:won_at_showdown] << p
          @game[:known_cards][p] = ::Regexp.last_match(1) if line =~ /showed \[(.+?)\]/
        when /collected \(\$?([\d.]+?)\)/
          @game[:winners][p] = ::Regexp.last_match(1).to_f
        when /lost|mucked/
          @game[:lost_at_showdown] << p
          @game[:known_cards][p] = ::Regexp.last_match(1) if line =~ /mucked \[(.+?)\]/
        when /folded before flop/
          @game[:folded_before_flop] << p
        end
      end

      def parse_showdown(line)
        return unless line =~ /^(.*?):/

        @game[:went_to_showdown] << ::Regexp.last_match(1)
      end

      def parse_street(line)
        return unless line.index(':')

        p, a = line.split(/:\s+/, 2)
        p = player_index(p)
        if a.start_with?('shows')
          a =~ /\[(.*)\]/
          @game[:known_cards][p] = ::Regexp.last_match(1)
        else
          @game[:bets][@state][p] ||= []
          @game[:bets][@state][p] << parse_action(a)
        end
      end

      def parse
        while (line = @file.gets)
          line.chomp!

          # game header
          case line
          when /PokerStars Game/

            yield @game if @game && block_given?

            parse_game(line)
            @state = :headers

          when /said/ # chat message
          when /\*\*\* (.*) \*\*\*/

            case ::Regexp.last_match(1)
            when 'FLOP'
              line =~ /\[(.*)\]/
              @game[:flop] = ::Regexp.last_match(1)
              @state = 'flop'
            when 'TURN'
              line =~ /\[([^\[]*?)\]$/
              @game[:turn] = ::Regexp.last_match(1)
              @state = 'turn'
            when 'RIVER'
              line =~ /\[([^\[]*?)\]$/
              @game[:river] = ::Regexp.last_match(1)
              @state = 'river'
            when 'SHOW DOWN'
              @state = :showdown
            when 'HOLE CARDS'
              @state = 'preflop'
            when 'SUMMARY'
              @state = :summary
            end

          else

            case @state
            when :headers
              parse_headers(line)
            when :summary
              parse_summary(line)
            when :showdown
              parse_showdown(line)
            when 'preflop'
              parse_preflop(line)
            else
              parse_street(line)
            end
          end
        end
      end
    end
  end
end
