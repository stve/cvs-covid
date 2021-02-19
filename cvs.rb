#!/usr/bin/env ruby

require "json"
require "mail"
require "http"

STATE = "NJ".freeze
URL = "https://www.cvs.com/immunizations/covid-19-vaccine.vaccine-status.#{STATE}.json?vaccineinfo"
REFERRER = "https://www.cvs.com/immunizations/covid-19-vaccine"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/88.0.4324.150 Safari/537.36"
APPOINTMENT_URL = "https://www.cvs.com/vaccine/intake/store/cvd-schedule?icid=coronavirus-lp-vaccine-sd-statetool"
RECIPIENTS = []

PREFERRED_LOCATIONS = Set.new(["HAZLET", "EAST BRUNSWICK", "FLEMINGTON", "GREEN BROOK", "PRINCETON", "WEST ORANGE"])

puts "Starting CVS COVID vaccine checker"
puts ""

def print_and_flush(str)
  print str
  $stdout.flush
end

def format(location)
  str = "#{location["city"]} (#{location["status"]})"
  str << ", #{location["totalAvailable"]} Available Appointments - #{location["pctAvailable"]}" if location['totalAvailable'].to_i > 0
  str
end

while true do
  # puts "Checking at #{Time.now}"

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

  headers = {
    "User-Agent" => USER_AGENT,
    "Referer" => REFERRER,
    :accept => "application/json",
  }

  response = HTTP.headers(headers).get(URL)
  if response.status.success?
    payload = response.parse
    locations = payload["responsePayloadData"]["data"][STATE]
    # puts "Locations reported: #{locations.size}"

    available = locations.select { |location| location["status"] !~ /booked/i }

    # available = [{"city" => "PRINCETON", "status" => "Available", "totalAvailable" => 20}]

    if available.any?
      preferred_available = available.select { |location| PREFERRED_LOCATIONS.include?(location["city"]) }
      preferred_cities = preferred_available.map { |location| format(location) }
      cities = available.map { |location| format(location) }

      # puts "Availabilities!"
      print_and_flush "!"
      # puts cities

      body = ""
      body << "Preferred Locations\n#{preferred_cities.join("\n")}\n\n" if preferred_cities.any?
      body << "All Available Locations\n#{cities.join("\n")}\n\n"
      body << "Book Appointment #{APPOINTMENT_URL}\n"

      mail = Mail.deliver do
        from ENV.fetch("FROM_EMAIL")
        to RECIPIENTS
        subject "CVS Vaccine Availabilities"
        body body
      end
    end
  else
    puts "x" # response.body.to_s
  end

  print_and_flush "."
  sleep 60
end
