require 'erubis'
require 'tabularize'
require 'java'

module JRubySQL
module Output
class Term
  include JRubySQL::Messages

  HELP = Erubis::Eruby.new(File.read File.join(File.dirname(__FILE__), '../doc/help.txt.erb')).result(binding)

  def initialize
    # Make use of JLine included in JRuby
    terminal =
      case JRUBY_VERSION
      when /^1\.7/
        Java::jline.console.ConsoleReader.new.getTerminal
      when /^1\.6/
        Java::jline.ConsoleReader.new.getTerminal
      end

    @get_terminal_size = lambda {
      case JRUBY_VERSION
      when /^1\.7/
        [ terminal.width, terminal.height ]
      when /^1\.6/
        [ terminal.getTerminalWidth, terminal.getTerminalHeight ]
      end
    }
    self.display_mode = :table
    trap 'INT' do
      Thread.main.raise Interrupt
    end
  end

  def welcome!
    puts JRubySQL.name
  end

  def cursor empty
    if empty
      'jrubysql> '
    else
      '       -> '
    end
  end

  def print_cursor empty
    print cursor(empty)
  end

  def print_help
    puts
    puts HELP
    puts
  end

  def info message
    puts "[I] #{message}"
  end

  def result message
    puts "[R] #{message}"
  end

  def warn message
    puts "[W] #{message}"
  end

  def error message
    puts "[E] #{message}"
  end

  def print_result ret
    # Footer
    elapsed = "(#{'%.2f' % ret[:elapsed]} sec)"

    if ret[:set?]
      begin
        cnt = send(@printer, ret[:result])
        result m(:rows_returned, cnt, cnt > 1 ? 's' : '', elapsed)
      rescue Interrupt
        warn m(:interrupted)
      end
    elsif ret[:result]
      cnt = [0, ret[:result]].max
      result m(:rows_affected, cnt, cnt > 1 ? 's' : '', elapsed)
    else
      result elapsed
    end
    puts
  end

  def display_mode= mode
    @printer = "print_#{mode}".to_sym
  end

private
  def print_pairs ret
    cnt = 0
    ret.each do |row|
      labels = row.labels.map { |e| e + ': ' }
      max_label_len = labels.map(&:length).max
      pairs = labels.zip row.to_a
      pairs.each_with_index do |pair, idx|
        print (idx == 0) ? '- ' : '  '
        l, v = pair
        print l.ljust(max_label_len, ' ')
        puts v.to_s
      end
      puts
      cnt += 1
    end
    cnt
  end

  def print_table ret, tabularize_opts = {}
    cnt = 0
    term_size = @get_terminal_size.call
    lines = [(term_size[1] rescue JRubySQL::Constants::MAX_SCREEN_ROWS) - 5,
             JRubySQL::Constants::MIN_SCREEN_ROWS].max
    cols = (term_size[0] rescue nil)
    ret.each_slice(lines) do |slice|
      cnt += slice.length

      table = Tabularize.new tabularize_opts
      table << slice.first.labels.map { |l| decorate_label l }
      table.separator!
      slice.each do |row|
        table << row.to_a.map { |v| decorate v }
      end
      puts table
    end
    cnt
  end

  def decorate_label label
    label
  end

  def decorate value
    case value
    when BigDecimal
      value.to_s('F')
    else
      value.to_s
    end
  end
end#Term
end#Output
end#JRubySQL

