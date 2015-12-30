#!/usr/bin/env ruby
# / Usage:
# /   --city=rotterdam
# /   --date=1-1-2016
# /   --hour=17
# /   --movieid=19723

require 'colorize'
require 'nokogiri'
require 'open-uri'
require 'optparse'
require 'screencap'

# Default options
@base_url = 'https://www.pathe.nl'
@city = 'rotterdam'
@date = '1-1-2016'
@hour = 10
@movie_id = 19_723

# Parse arguments
ARGV.options do |opts|
  opts.on('--city=val') { |val| @city = val }
  opts.on('--date=val') { |val| @date = val }
  opts.on('--hour=val') { |val| @hour = val.to_i }
  opts.on('--movieid=val') { |val| @movie_id = val }
  opts.on_tail('--help') { exec "grep ^#/<'#{__FILE__}'|cut -c4-" }
  opts.parse!
end

def start
  movies = []
  doc = Nokogiri::HTML(open("#{@base_url}/bioscoopagenda/#{@city}/film/#{@movie_id}?date=#{@date}"))
  doc.css('a.is-themed').each do |btn|
    text = btn.text.to_s.gsub(/[^0-9A-Za-z:]/m, '')
    info = /([0-9]{2}):([0-9]{2})([A-Za-z3]+)/i.match(text)
    movies << {
      hall: nil,
      hall_url: nil,
      time: {
        hours: info[1],
        minutes: info[2]
      },
      type: info[3],
      url: btn['href']
    } if info[1].to_i >= @hour
  end

  find_seats(movies)
end

def find_seats(movies)
  movies.each do |movie|
    open("#{@base_url}/#{movie[:url]}") do |resp|
      hall = resp.base_uri.to_s.split('/').last
      movie[:hall] = resp.base_uri.to_s.split('/').last
      movie[:hall_url] = "#{@base_url}/tickets/#{hall}"
      check_for_free_seats(movie)
    end
  end
end

def check_for_free_seats(movie)
  puts "#{movie[:time][:hours]}:#{movie[:time][:minutes]} - #{movie[:type]} - #{movie[:hall_url]}".colorize(:blue)
  doc = Nokogiri::HTML(open("#{movie[:hall_url]}/stoelen"))

  all_seats = doc.css('#seats li').size
  sold_seats = doc.css('#seats li.seat-sold').size
  free_seats = all_seats - sold_seats
  free_percentage = (free_seats.to_f / all_seats.to_f * 100).ceil

  if free_seats < all_seats
    percentage = "#{free_percentage}% available".colorize(:green)
    puts "#{percentage} - #{free_seats} out of #{all_seats}"
    take_screencap(movie)
  else
    puts 'No seats available :('.colorize(:red)
  end
end

def take_screencap(movie)
  f = Screencap::Fetcher.new("#{movie[:hall_url]}/stoelen")
  f.fetch(
    output: "screencaps/#{movie[:time][:hours]}#{movie[:time][:minutes]}-#{movie[:hall]}.png",
    div: '#contain',
    width: 780,
    height: 431
  )
end

start
