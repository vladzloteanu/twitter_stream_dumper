#!/usr/bin/env ruby

require "rubygems"
require "bundler/setup"

require 'tweetstream'
require 'active_support/all'
require 'yaml'
require 'csv'
require 'language_detector'
require 'optparse'
require 'ostruct'

# Dirty fix for language detector incorrect yml issue
YAML::ENGINE.yamler = 'syck'

class TweetListener

  attr_reader :options

  def initialize(options)
    @options = options
  end

  def start!
    configure!
    listen!
  end

  def config
    file_path = File.expand_path(File.join(File.dirname(__FILE__), 'config/twitter.yml'))
    @config ||= YAML.load(File.open(file_path))
  end

  def configure!
    TweetStream.configure do |tweet_stream_config|
      %w( consumer_key consumer_secret oauth_token oauth_token_secret auth_method ).each do |param|
        tweet_stream_config.send("#{param}=", config[param])
      end
    end
    debug "Configured client."
  end

  def client
    TweetStream::Client.new
  end

  def listen!
    debug "Connecting.."

    client.on_error do |message|
      error message
    end

    client.on_limit do |skip_count|
      error "Limited: #{skip_count}"
    end

    client.on_enhance_your_calm do
      error "Enhance your calm."
    end

    debug "Start tracking: #{options.search.inspect} (language restriction: #{options.languages})"
    client.track(*options.search) do |status|
      with_error_handling do
        tweet_decorator = TweetDecorator.new(status)
        if should_keep?(tweet_decorator)
          debug "Accepting '#{tweet_decorator.extract}'"
          log_line(tweet_decorator.to_csv)
        else
          debug "Rejecting '#{tweet_decorator.extract}' [Language: #{tweet_decorator.language}]"
        end
      end
    end

  end

  def should_keep?(ls)
    options.languages.empty? || options.languages.include?(ls.language.to_s)
  end

  def with_error_handling(&block)
    begin
      yield
    rescue => e
      error "Error: #{e}"
      e.backtrace.each{|line| debug " > #{line}"}
    end
  end

  def log_line(csv_line)
    puts csv_line
  end

  def debug(msg)
    $stderr.puts(msg) if options.verbose
  end

  def error(msg)
    $stderr.puts "ERROR: #{msg}"
  end

end

class TweetDecorator

  attr_reader :status

  def initialize(status)
    @status = status
    @data = {}
  end

  def to_csv
    parse!
    @data.values.to_csv
  end

  def extract
    status.text.truncate(45).gsub(/[\r|\n]/, "")
  end

  def language
    @language = (status.iso_language_code || lang_detector.detect(status.text.to_s))
  end

  def parse!
    clean!

    self.add! "created_at", status.created_at

    self.add! "body", status.text
    self.add! "language", language

    self.add! "user_name", status.user.name
    self.add! "user_screen_name", status.user.screen_name
    self.add! "user_description", status.user.description

    self.add! "user_lang", status.user.lang
    self.add! "user_time_zone", status.user.time_zone

    self.add! "user_followers_count", status.user.followers_count
    self.add! "user_friends_count", status.user.friends_count
    self.add! "user_statuses_count", status.user.statuses_count
  end

  def add! key, value
    @data[key] = value
  end

  def clean!
    @data = {}
  end

  def lang_detector
    @lang_detector ||= LangDetector.new
  end

end

class LangDetector

  def detect(text)
    detector.detect(text)
  end

  def detector
    @detector ||= LanguageDetector.new('tc')
  end

end

options = OpenStruct.new
options.search = []
options.languages = []
options.verbose = false

OptionParser.new do |opts|
  opts.banner = 'Usage: ./dump_statuses.rb --search "bandyou","b-and-you","bouygues","bouyguestelecom" --languages french,fr,catalan --verbose >> btel_tweets.csv '

  opts.on("--languages 'fr','french'", Array, "Only keep language(s)") do |l|
    options.languages = l
  end

  opts.on("-v", "--verbose", "Verbose mode") do |v|
    options.verbose = v
  end

  opts.on("--search 'orange','france telecom'", Array, "Search arguments") do |list|
    options.search = list
  end
end.parse!
raise "At least one search option must be given" if options.search.empty?

TweetListener.new(options).start!

