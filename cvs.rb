#!/usr/bin/env ruby

require "dotenv"
require "open-uri"
require "json"
require "mail"

Dotenv.load

URL = "https://www.cvs.com/immunizations/covid-19-vaccine.vaccine-status.VA.json?vaccineinfo"
REFERRER = "https://www.cvs.com/immunizations/covid-19-vaccine"

puts "Starting CVS COVID vaccine checker"
puts ""

while true do
  puts "Checking at #{Time.now}"

  Mail.defaults do
    delivery_method(
      :smtp,
      address: "smtp.gmail.com",
      port: 587,
      user_name: ENV.fetch("SMTP_USERNAME"),
      password: ENV.fetch("SMTP_PASSWORD"),
      enable_ssl: true
    )
  end

  open(URL, "Referer" => REFERRER) do |f|
    payload = JSON.parse(f.read)
    locations = payload["responsePayloadData"]["data"]["VA"]

    available = locations.select { |location| location["status"] !~ /booked/i }

    if available.any?
      cities = available.map { |location| "#{location["city"]} (#{location["status"]}, #{location["totalAvailable"]} available)" }

      puts "Availabilities!"
      puts cities

      mail = Mail.deliver do
        from ENV.fetch("FROM_EMAIL")
        to ENV.fetch("TO_EMAIL")
        subject "CVS availabilities"
        body cities.join("\n")
      end
    else
      puts "Nothing found :("
    end
  end

  puts "-----\n"
  sleep 300
end
