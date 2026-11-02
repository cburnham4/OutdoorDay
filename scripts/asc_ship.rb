#!/usr/bin/env ruby
# frozen_string_literal: true
# Outdoor Day — once the ASC *app record* exists, upload IPA + push listing fields.
# Usage: ruby scripts/asc_ship.rb
# Requires: IPA at build/OutdoorDay.ipa, AuthKey at ASC_KEY_PATH (or default).

require "openssl"
require "base64"
require "json"
require "net/http"
require "uri"
require "pathname"

ROOT = Pathname.new(__dir__).parent
BUNDLE_ID = "us.letshang.outdoor-day"
IPA = ROOT.join("build/OutdoorDay.ipa")
KEY_ID = ENV.fetch("ASC_KEY_ID", "CPZ7YXKKGD")
ISSUER = ENV.fetch("ASC_ISSUER", "69a6de87-65f4-47e3-e053-5b8c7c11a4d1")
KEY_PATH = ENV["ASC_KEY_PATH"] || [
  "/Users/carlburnham/Documents/coding/Ios Projects/LetsHangIOS/SunriseSunsetIos/AuthKey_CPZ7YXKKGD.p8",
  "/Users/carlburnham/Documents/coding/TruthFinder/fastlane/AuthKey_CPZ7YXKKGD.p8"
].find { |p| File.exist?(p) } || abort("ASC AuthKey .p8 not found; set ASC_KEY_PATH")

def b64url(data)
  Base64.urlsafe_encode64(data).delete("=")
end

def token
  header = b64url({ alg: "ES256", kid: KEY_ID, typ: "JWT" }.to_json)
  now = Time.now.to_i
  payload = b64url({ iss: ISSUER, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" }.to_json)
  key = OpenSSL::PKey::EC.new(File.read(KEY_PATH))
  der = key.sign(OpenSSL::Digest::SHA256.new, "#{header}.#{payload}")
  asn1 = OpenSSL::ASN1.decode(der)
  r = asn1.value[0].value.to_s(2)
  s = asn1.value[1].value.to_s(2)
  r = ("\x00" * (32 - r.bytesize) + r)[-32..]
  s = ("\x00" * (32 - s.bytesize) + s)[-32..]
  "#{header}.#{payload}.#{b64url(r + s)}"
end

$token = token

def request(method, path, body: nil, attempts: 3)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  last_error = nil
  attempts.times do |i|
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 60
      http.read_timeout = 180
      req = case method
            when :get then Net::HTTP::Get.new(uri)
            when :post then Net::HTTP::Post.new(uri)
            when :patch then Net::HTTP::Patch.new(uri)
            end
      req["Authorization"] = "Bearer #{$token}"
      if body
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(body)
      end
      res = http.request(req)
      parsed = begin
        JSON.parse(res.body.to_s.force_encoding("UTF-8"))
      rescue StandardError
        { "raw" => res.body.to_s }
      end
      return [res.code.to_i, parsed]
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::ETIMEDOUT => e
      last_error = e
      sleep(2 ** i)
    end
  end
  raise last_error
end

def read_meta(name)
  ROOT.join("fastlane/metadata/en-US/#{name}.txt").read.strip
end

def read_root_meta(name)
  ROOT.join("fastlane/metadata/#{name}.txt").read.strip
end

puts "== Outdoor Day ASC ship =="
abort("Missing IPA at #{IPA}") unless IPA.file?

code, data = request(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")
abort("ASC apps lookup failed #{code}: #{data}") unless code == 200
app = data["data"]&.first
unless app
  puts "NO_APP: Create Outdoor Day in App Store Connect for bundle #{BUNDLE_ID}, then re-run."
  exit 2
end

app_id = app["id"]
puts "APP #{app_id} #{app.dig('attributes', 'name')}"

# Ensure version 1.0 exists
code, versions = request(:get, "/v1/apps/#{app_id}/appStoreVersions?filter[platform]=IOS&limit=10")
version = (versions["data"] || []).find { |v| v.dig("attributes", "versionString") == "1.0" }
unless version
  code, created = request(:post, "/v1/appStoreVersions", body: {
    data: {
      type: "appStoreVersions",
      attributes: { platform: "IOS", versionString: "1.0" },
      relationships: { app: { data: { type: "apps", id: app_id } } }
    }
  })
  abort("create version failed #{code}: #{created}") unless (200..299).cover?(code)
  version = created["data"]
end
version_id = version["id"]
puts "VERSION #{version_id} state=#{version.dig('attributes', 'appStoreState')}"

# Localization en-US
code, locs = request(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations")
loc = (locs["data"] || []).find { |l| l.dig("attributes", "locale") == "en-US" }
attrs = {
  description: read_meta("description"),
  keywords: read_meta("keywords"),
  marketingUrl: read_meta("marketing_url"),
  promotionalText: read_meta("promotional_text"),
  supportUrl: read_meta("support_url"),
  whatsNew: read_meta("release_notes")
}
if loc
  code, patched = request(:patch, "/v1/appStoreVersionLocalizations/#{loc['id']}", body: {
    data: { type: "appStoreVersionLocalizations", id: loc["id"], attributes: attrs }
  })
  puts "LOC_PATCH #{code}"
  abort("loc patch failed #{patched}") unless (200..299).cover?(code)
  loc_id = loc["id"]
else
  code, created = request(:post, "/v1/appStoreVersionLocalizations", body: {
    data: {
      type: "appStoreVersionLocalizations",
      attributes: attrs.merge(locale: "en-US"),
      relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version_id } } }
    }
  })
  puts "LOC_CREATE #{code}"
  abort("loc create failed #{created}") unless (200..299).cover?(code)
  loc_id = created.dig("data", "id")
end

# App info subtitle / name / categories / copyright
code, infos = request(:get, "/v1/apps/#{app_id}/appInfos")
info = infos["data"]&.first
if info
  primary = read_root_meta("primary_category")
  secondary = read_root_meta("secondary_category")
  copyright = read_root_meta("copyright")
  code, patched_info = request(:patch, "/v1/appInfos/#{info['id']}", body: {
    data: {
      type: "appInfos",
      id: info["id"],
      attributes: {},
      relationships: {
        primaryCategory: { data: { type: "appCategories", id: primary } },
        secondaryCategory: { data: { type: "appCategories", id: secondary } }
      }
    }
  })
  puts "APP_INFO_CATS #{code} primary=#{primary} secondary=#{secondary}"
  puts patched_info.to_json[0, 300] unless (200..299).cover?(code)

  request(:patch, "/v1/apps/#{app_id}", body: {
    data: { type: "apps", id: app_id, attributes: { contentRightsDeclaration: "DOES_NOT_USE_THIRD_PARTY_CONTENT" } }
  })
  # Copyright lives on the version
  request(:patch, "/v1/appStoreVersions/#{version_id}", body: {
    data: { type: "appStoreVersions", id: version_id, attributes: { copyright: copyright } }
  })
  puts "COPYRIGHT #{copyright}"

  code, info_locs = request(:get, "/v1/appInfos/#{info['id']}/appInfoLocalizations")
  info_loc = (info_locs["data"] || []).find { |l| l.dig("attributes", "locale") == "en-US" }
  if info_loc
    request(:patch, "/v1/appInfoLocalizations/#{info_loc['id']}", body: {
      data: {
        type: "appInfoLocalizations",
        id: info_loc["id"],
        attributes: {
          name: read_meta("name"),
          subtitle: read_meta("subtitle"),
          privacyPolicyUrl: read_meta("privacy_url")
        }
      }
    })
    puts "APP_INFO_LOC patched"
  end
end

# Upload IPA via altool
puts "Uploading IPA…"
cmd = [
  "xcrun", "altool", "--upload-app", "--type", "ios",
  "--file", IPA.to_s,
  "--apiKey", KEY_ID,
  "--apiIssuer", ISSUER
]
ok = system(*cmd)
abort("altool upload failed") unless ok

puts "DONE_BASE: IPA + metadata enqueued. Next: attach build, IAP, screenshots, submit (scripts/asc_finish.rb or agent)."
puts "LOC_ID=#{loc_id} VERSION_ID=#{version_id} APP_ID=#{app_id}"
