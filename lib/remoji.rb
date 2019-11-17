#!/usr/bin/env ruby
require 'fileutils'
require 'pathname'
require 'optparse'
require 'ostruct'
require 'json'
require 'pry'
require 'nokogiri'
require 'open-uri'
require 'awesome_print'

# The Remoji command
class Remoji # rubocop:disable Metrics/ClassLength
  EMOJI_TABLE = 'http://unicode.org/emoji/charts/full-emoji-list.html'.freeze

  def self.run!(args)
    new.execute! args
  end

  def categories
    @categories ||= filter_hash.map { |_k, v| v[:cat] }.uniq
  end

  def subcategories
    @subcategories ||= filter_hash.map { |_k, v| v[:subcat] }.uniq
  end

  def find_medhead(elem)
    return medhead(elem).text if medhead(elem)

    find_medhead(elem.previous_sibling)
  end

  def medhead(elem)
    elem.css('th[class=mediumhead]').empty? ? nil : elem.css('th[class=mediumhead]')
  end

  def find_bighead(elem)
    return bighead(elem).text if bighead(elem)

    find_bighead(elem.previous_sibling)
  end

  def bighead(elem)
    elem.css('th[class=bighead]').empty? ? nil : elem.css('th[class=bighead]')
  end

  def emoji_table
    doc = Nokogiri(open(EMOJI_TABLE).read) # rubocop:disable Security/Open
    tds = doc.xpath('//table/tr/td')
    tds.each_slice 15
  end

  def import_emojis!
    hash = {}
    emoji_table.each do |n|
      hash[n.last.text] = {
        code: n[1].text,
        sym: n[2].text,
        cat: find_bighead(n.last.parent),
        subcat: find_medhead(n.last.parent)
      }
    end
    emoji_file.open('w+') { |f| f.puts JSON.pretty_generate(hash) }
  end

  def initialize
    @options = OpenStruct.new verbose: 0
    verify_cache!
  end

  def emoji_file
    return @emoji_file if @emoji_file

    local = Pathname(ENV['HOME']).join('.local/remoji')
    FileUtils.mkdir_p local.to_s unless local.exist?
    @emoji_file = local.join('emojis.json')
  end

  def verify_cache!
    return if emoji_file.exist?

    warn "No #{@emoji_file} found. Import?"
    yn = $stdin.getc
    unless yn =~ /^y/i
      warn 'Ok, Bailing!'
      exit 1
    end
    warn 'Ok, importing'
    import_emojis!
  end

  def filter_array
    @filter_array ||= filter_hash.to_a
  end

  def filter_hash
    return @filter_hash if @filter_hash

    db = JSON.parse(emoji_file.read, symbolize_names: true)
    @filter_hash = if @options.subcat
                     db.select { |_k, v| v[:subcat] =~ /#{@options.subcat}/i }
                   elsif @options.cat
                     db.select { |_k, v| v[:cat] =~ /#{@options.cat}/i }
                   else
                     db
                   end
  end

  def execute!(args)
    parse_opts! args

    if args.empty?
      output filter_array
      exit
    end

    found = []
    args.each do |arg|
      found << if arg.match?(/^S:/)
                 arg
               else
                 find_in_filter_array(arg)
               end
    end

    output found.compact.flatten 1
  end

  def find_in_filter_array(arg)
    find_in_filter_hash(arg).to_a || []
  end

  def find_in_filter_hash(arg)
    filter_hash.select do |k, _v|
      s = k.to_s
      if @options.exact
        s == arg
      elsif @options.regex
        s =~ /#{arg}/
      else
        s =~ /#{arg}/i
      end
    end
  end

  def parse_opts!(args)
    OptionParser.new do |o|
      o.banner = "#{$PROGRAM_NAME} [options] EMOJI ANOTHER_EMOJI ..."
      o.separator 'Where EMOJI is an emoji name to search for'
      %i[cat subcat details cats subcats verbose exact regex].each do |sym|
        send "#{sym}_opt".to_sym, o
      end
      o.on('-h', '--help') do
        puts o
        exit
      end
    end.parse!(args)
  end

  def exact_opt(opt)
    opt.on('-e', '--exact', 'Exactly match the emoji given, do not search for it') { @options.exact = true }
  end

  def regex_opt(opt)
    opt.on('-r', '--regex', 'Consider each argument a regular expression') { @options.regex = true }
  end

  def verbose_opt(opt)
    opt.on('-v', '--verbose', 'Increase verbosity') { @options.verbose += 1 }
  end

  def cats_opt(opt)
    opt.on('--subs', '--subcategories', 'List subcategories') do
      ap subcategories
      exit
    end
  end

  def subcats_opt(opt)
    opt.on('--cats', '--categories', 'List Categories') do
      ap categories
      exit
    end
  end

  def subcat_opt(opt)
    opt.on('-sCAT', '--subcat CAT', 'Find matches in a subcategory') { |s| @options.subcat = s }
  end

  def cat_opt(opt)
    opt.on('-cCAT', '--cat CAT', 'Find matches in a category') { |s| @options.cat = s }
  end

  def details_opt(opt)
    opt.on('-n', '--no-details', 'Just print the emojis') { |_| @options.no = true }
  end

  def die!(msg, code = 1)
    warn msg
    exit code
  end

  def output(them)
    puts display(them)
  end

  def display(them) # rubocop:disab
    die! 'No matching emojis found', 2 if them.empty?

    join_char = @options.no ? ' ' : "\n"
    them.map do |name, attrs|
      attrs ||= { sym: name.split('S:').last, type: 'Raw String' }
      if @options.no
        attrs[:sym]
      elsif @options.verbose.positive?
        "#{name}: #{attrs}"
      else
        [attrs[:sym], name].join(' : ')
      end
    end.join(join_char).squeeze(join_char)
  end
end

Remoji.run! ARGV if $PROGRAM_NAME == __FILE__
# vim: set et sts=2 sw=2 ts=2 syntax=ruby foldmethod=syntax:
