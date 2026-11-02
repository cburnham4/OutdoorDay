#!/usr/bin/env ruby
# frozen_string_literal: true
# Create Outdoor Day in ASC via Spaceship (needs Apple ID password + 2FA).
#
# Usage:
#   SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER="+1 (503) 929-7690" \
#   FASTLANE_USER=cburnhamiv@gmail.com \
#   FASTLANE_PASSWORD='…' \
#   SPACESHIP_2FA_CODE=123456 \
#   bundle exec ruby scripts/asc_create_interactive.rb
#
# Or rely on keychain deliver.* password and type the SMS code when prompted
# in an interactive terminal.

require "spaceship"
require "open3"

BUNDLE = "us.letshang.outdoor-day"
NAME = "Outdoor Day"
SKU = "outdoor-day-001"

def keychain_password(service)
  out, status = Open3.capture2("security", "find-internet-password", "-s", service, "-w")
  return out.strip if status.success? && !out.strip.empty?
  out, status = Open3.capture2("security", "find-generic-password", "-s", service, "-w")
  status.success? ? out.strip : nil
end

user = ENV["FASTLANE_USER"] || "cburnhamiv@gmail.com"
pass = ENV["FASTLANE_PASSWORD"] || ENV["FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD"] ||
       keychain_password("deliver.#{user}") ||
       keychain_password("deliver.appspecific.#{user}")
abort("No password: set FASTLANE_PASSWORD or store deliver.#{user} in keychain") if pass.to_s.empty?

if (code = ENV["SPACESHIP_2FA_CODE"].to_s.strip) && !code.empty?
  # Preload stdin for the 2FA prompt Spaceship will raise.
  require "stringio"
  $stdin = StringIO.new("#{code}\n")
end

puts "Logging into ASC as #{user}…"
Spaceship::ConnectAPI.login(user, pass)
Spaceship::ConnectAPI.select_team if Spaceship::ConnectAPI.client.teams.size > 1

apps = Spaceship::ConnectAPI::App.all
hit = apps.find { |a| a.bundle_id == BUNDLE }
if hit
  puts "ALREADY_EXISTS id=#{hit.id}"
  exit 0
end

puts "Creating #{NAME} (#{BUNDLE})…"
app = Spaceship::ConnectAPI::App.create(
  name: NAME,
  primary_locale: "en-US",
  version_string: "1.0",
  sku: SKU,
  bundle_id_identifier: BUNDLE,
  platforms: ["IOS"]
)
puts "CREATED id=#{app.id}"
puts "Next: bash scripts/asc_ship_all.sh (or wait for asc_wait_and_ship)."
