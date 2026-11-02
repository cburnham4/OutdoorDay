#!/usr/bin/env ruby
# frozen_string_literal: true
# Outdoor Day finish: IAP, age rating, screenshots, attach build, submit.
# Usage: ruby scripts/asc_finish.rb

require "openssl"
require "base64"
require "json"
require "net/http"
require "uri"
require "pathname"
require "digest"

ROOT = Pathname.new(__dir__).parent
BUNDLE_ID = "us.letshang.outdoor-day"
PRODUCT_ID = "us.letshang.outdoor_day.remove_ads"
KEY_ID = ENV.fetch("ASC_KEY_ID", "CPZ7YXKKGD")
ISSUER = ENV.fetch("ASC_ISSUER", "69a6de87-65f4-47e3-e053-5b8c7c11a4d1")
KEY_PATH = ENV["ASC_KEY_PATH"] || [
  "/Users/carlburnham/Documents/coding/Ios Projects/LetsHangIOS/SunriseSunsetIos/AuthKey_CPZ7YXKKGD.p8",
  "/Users/carlburnham/Documents/coding/TruthFinder/fastlane/AuthKey_CPZ7YXKKGD.p8"
].find { |p| File.exist?(p) } || abort("ASC AuthKey .p8 not found; set ASC_KEY_PATH")
TARGET_USD_PRICE = ENV.fetch("IAP_USD_PRICE", "2.99")

SCREENSHOT_MAP = {
  "APP_IPHONE_65" => /iPhone 6\.5".*\.png\z/,
  "APP_IPHONE_67" => /iPhone 6\.7".*\.png\z/,
  "APP_IPHONE_69" => /iPhone 6\.9".*\.png\z/
}.freeze

def b64url(data)
  Base64.urlsafe_encode64(data).delete("=")
end

def mint_token
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

$token = mint_token

def request(method, path, body: nil)
  uri = URI("https://api.appstoreconnect.apple.com#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 30
  http.read_timeout = 180
  req = case method
        when :get then Net::HTTP::Get.new(uri)
        when :post then Net::HTTP::Post.new(uri)
        when :patch then Net::HTTP::Patch.new(uri)
        else raise "bad method"
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
  [res.code.to_i, parsed]
end

puts "== Outdoor Day ASC finish =="
code, data = request(:get, "/v1/apps?filter[bundleId]=#{BUNDLE_ID}")
abort("apps lookup failed #{code}") unless code == 200
app = data["data"]&.first
abort("NO_APP: create ASC app for #{BUNDLE_ID} first") unless app
app_id = app["id"]
puts "APP #{app_id}"

_code, versions = request(:get, "/v1/apps/#{app_id}/appStoreVersions?filter[platform]=IOS&limit=10")
version = (versions["data"] || []).find { |v| v.dig("attributes", "versionString") == "1.0" } || versions["data"]&.first
abort("No appStoreVersion") unless version
version_id = version["id"]
puts "VERSION #{version_id} state=#{version.dig('attributes', 'appStoreState')}"

_code, locs = request(:get, "/v1/appStoreVersions/#{version_id}/appStoreVersionLocalizations")
loc = (locs["data"] || []).find { |l| l.dig("attributes", "locale") == "en-US" } || locs["data"]&.first
abort("No en-US localization — run asc_ship.rb first") unless loc
loc_id = loc["id"]
puts "LOC #{loc_id}"

_code, infos = request(:get, "/v1/apps/#{app_id}/appInfos")
info = infos["data"]&.first
if info
  _code, age = request(:get, "/v1/appInfos/#{info['id']}/ageRatingDeclaration")
  if age["data"]
    age_id = age["data"]["id"]
    attrs = {
      advertising: true,
      healthOrWellnessTopics: true,
      socialMedia: false,
      unrestrictedWebAccess: false,
      userGeneratedContent: false,
      messagingAndChat: false,
      gambling: false,
      gamblingSimulated: "NONE",
      contests: "NONE",
      alcoholTobaccoOrDrugUseOrReferences: "NONE",
      medicalOrTreatmentInformation: "NONE",
      horrorOrFearThemes: "NONE",
      matureOrSuggestiveThemes: "NONE",
      profanityOrCrudeHumor: "NONE",
      sexualContentOrNudity: "NONE",
      sexualContentGraphicAndNudity: "NONE",
      violenceCartoonOrFantasy: "NONE",
      violenceRealistic: "NONE",
      violenceRealisticProlongedGraphicOrSadistic: "NONE",
      gunsOrOtherWeapons: "NONE"
    }
    code, _ = request(:patch, "/v1/ageRatingDeclarations/#{age_id}", body: {
      data: { type: "ageRatingDeclarations", id: age_id, attributes: attrs }
    })
    puts "AGE_RATING #{code}"
  end
end

_code, iaps = request(:get, "/v1/apps/#{app_id}/inAppPurchasesV2?limit=50")
iap = (iaps["data"] || []).find { |p| p.dig("attributes", "productId") == PRODUCT_ID }
unless iap
  code, created = request(:post, "/v1/inAppPurchases", body: {
    data: {
      type: "inAppPurchases",
      attributes: {
        name: "Outdoor Day Plus",
        productId: PRODUCT_ID,
        inAppPurchaseType: "NON_CONSUMABLE"
      },
      relationships: { app: { data: { type: "apps", id: app_id } } }
    }
  })
  if (200..299).cover?(code)
    iap = created["data"]
    puts "IAP_CREATE #{iap['id']}"
  else
    puts "IAP_CREATE #{code}: #{created.to_json[0, 400]}"
  end
end
puts "IAP #{iap && iap['id']}" if iap

if iap
  iap_id = iap["id"]
  _code, iap_locs = request(:get, "/v1/inAppPurchases/#{iap_id}/inAppPurchaseLocalizations")
  unless (iap_locs["data"] || []).any? { |l| l.dig("attributes", "locale") == "en-US" }
    code, _ = request(:post, "/v1/inAppPurchaseLocalizations", body: {
      data: {
        type: "inAppPurchaseLocalizations",
        attributes: {
          name: "Outdoor Day Plus",
          description: "Remove ads and unlock the multi-day outdoor outlook.",
          locale: "en-US"
        },
        relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap_id } } }
      }
    })
    puts "IAP_LOC #{code}"
  end

  # Price schedule — required for paid unlock revenue path ($2.99 default).
  code, points = request(:get, "/v2/inAppPurchases/#{iap_id}/pricePoints?filter[territory]=USA&limit=200")
  price_point = (points["data"] || []).find { |p| p.dig("attributes", "customerPrice").to_s == TARGET_USD_PRICE }
  price_point ||= (points["data"] || []).min_by { |p| (p.dig("attributes", "customerPrice").to_f - TARGET_USD_PRICE.to_f).abs }
  if price_point
    temp_price_id = "${price1}"
    code, priced = request(:post, "/v1/inAppPurchasePriceSchedules", body: {
      data: {
        type: "inAppPurchasePriceSchedules",
        relationships: {
          inAppPurchase: { data: { type: "inAppPurchases", id: iap_id } },
          baseTerritory: { data: { type: "territories", id: "USA" } },
          manualPrices: { data: [{ type: "inAppPurchasePrices", id: temp_price_id }] }
        }
      },
      included: [
        {
          type: "inAppPurchasePrices",
          id: temp_price_id,
          attributes: { startDate: nil },
          relationships: {
            inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap_id } },
            inAppPurchasePricePoint: { data: { type: "inAppPurchasePricePoints", id: price_point["id"] } }
          }
        }
      ]
    })
    puts "IAP_PRICE #{code} usd=#{price_point.dig('attributes', 'customerPrice')} point=#{price_point['id']}"
    puts priced.to_json[0, 400] unless (200..299).cover?(code)
  else
    puts "IAP_PRICE skip: no USA price points (#{code})"
  end

  # Submit IAP for review when possible
  code, submitted_iap = request(:post, "/v1/inAppPurchaseSubmissions", body: {
    data: {
      type: "inAppPurchaseSubmissions",
      relationships: { inAppPurchaseV2: { data: { type: "inAppPurchases", id: iap_id } } }
    }
  })
  puts "IAP_SUBMIT #{code}"
  puts submitted_iap.to_json[0, 300] unless (200..299).cover?(code)
end

shot_dir = ROOT.join("fastlane/screenshots/en-US")
_code, sets = request(:get, "/v1/appStoreVersionLocalizations/#{loc_id}/appScreenshotSets")
existing = {}
(sets["data"] || []).each { |s| existing[s.dig("attributes", "screenshotDisplayType")] = s }

SCREENSHOT_MAP.each do |display_type, pattern|
  files = shot_dir.children.select { |p| p.file? && p.basename.to_s.match?(pattern) }.sort_by(&:to_s)
  if files.empty?
    puts "SHOTS skip #{display_type}: no files"
    next
  end
  set = existing[display_type]
  unless set
    code, created = request(:post, "/v1/appScreenshotSets", body: {
      data: {
        type: "appScreenshotSets",
        attributes: { screenshotDisplayType: display_type },
        relationships: {
          appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: loc_id } }
        }
      }
    })
    unless (200..299).cover?(code)
      puts "SHOT_SET_CREATE #{display_type} #{code}: #{created.to_json[0, 300]}"
      next
    end
    set = created["data"]
  end
  set_id = set["id"]
  _code, current = request(:get, "/v1/appScreenshotSets/#{set_id}/appScreenshots")
  if (current["data"] || []).length >= files.length
    puts "SHOTS #{display_type} already #{current['data'].length}"
    next
  end

  files.each do |path|
    bytes = path.binread
    code, reserved = request(:post, "/v1/appScreenshots", body: {
      data: {
        type: "appScreenshots",
        attributes: { fileName: path.basename.to_s, fileSize: bytes.bytesize },
        relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: set_id } } }
      }
    })
    unless (200..299).cover?(code)
      puts "SHOT_RESERVE fail #{path.basename}: #{code} #{reserved.to_json[0, 300]}"
      next
    end
    shot = reserved["data"]
    ops = shot.dig("attributes", "uploadOperations") || []
    ops.each do |op|
      upload_uri = URI(op["url"])
      http = Net::HTTP.new(upload_uri.host, upload_uri.port)
      http.use_ssl = upload_uri.scheme == "https"
      req = Net::HTTP::Put.new(upload_uri)
      (op["requestHeaders"] || []).each { |h| req[h["name"]] = h["value"] }
      offset = op["offset"].to_i
      length = op["length"].to_i
      req.body = bytes.byteslice(offset, length)
      res = http.request(req)
      puts "SHOT_PUT #{path.basename} #{res.code}"
    end
    checksum = Digest::MD5.base64digest(bytes)
    code, _ = request(:patch, "/v1/appScreenshots/#{shot['id']}", body: {
      data: {
        type: "appScreenshots",
        id: shot["id"],
        attributes: { uploaded: true, sourceFileChecksum: checksum }
      }
    })
    puts "SHOT_COMMIT #{path.basename} #{code}"
  end
end

# App Review contact + notes
def read_review(name)
  ROOT.join("fastlane/metadata/en-US/review_information/#{name}.txt").read.strip
rescue StandardError
  ""
end

_code, review = request(:get, "/v1/appStoreVersions/#{version_id}/appStoreReviewDetail")
review_detail = review["data"]
review_attrs = {
  contactFirstName: read_review("first_name"),
  contactLastName: read_review("last_name"),
  contactEmail: read_review("email_address"),
  contactPhone: read_review("phone_number"),
  notes: read_review("notes")
}.reject { |_, v| v.nil? || v.empty? }
if review_detail
  code, _ = request(:patch, "/v1/appStoreReviewDetails/#{review_detail['id']}", body: {
    data: { type: "appStoreReviewDetails", id: review_detail["id"], attributes: review_attrs }
  })
  puts "REVIEW_DETAIL_PATCH #{code}"
elsif !review_attrs.empty?
  code, created_review = request(:post, "/v1/appStoreReviewDetails", body: {
    data: {
      type: "appStoreReviewDetails",
      attributes: review_attrs,
      relationships: { appStoreVersion: { data: { type: "appStoreVersions", id: version_id } } }
    }
  })
  puts "REVIEW_DETAIL_CREATE #{code}"
  puts created_review.to_json[0, 300] unless (200..299).cover?(code)
end

_code, builds = request(:get, "/v1/builds?filter[app]=#{app_id}&sort=-uploadedDate&limit=5")
build = (builds["data"] || []).find { |b| b.dig("attributes", "processingState") == "VALID" }
if build
  code, _ = request(:patch, "/v1/appStoreVersions/#{version_id}", body: {
    data: {
      type: "appStoreVersions",
      id: version_id,
      relationships: { build: { data: { type: "builds", id: build["id"] } } }
    }
  })
  puts "BUILD_ATTACH #{build['id']} #{code}"
else
  puts "BUILD_ATTACH skip: waiting for VALID build (run asc_ship.rb first)"
end

_code, subs = request(:get, "/v1/apps/#{app_id}/reviewSubmissions?filter[platform]=IOS")
sub = (subs["data"] || []).find { |s| %w[READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW].include?(s.dig("attributes", "state")) }
unless sub
  code, created = request(:post, "/v1/reviewSubmissions", body: {
    data: {
      type: "reviewSubmissions",
      attributes: { platform: "IOS" },
      relationships: { app: { data: { type: "apps", id: app_id } } }
    }
  })
  if (200..299).cover?(code)
    sub = created["data"]
    puts "REVIEW_CREATE #{sub['id']}"
  else
    puts "REVIEW_CREATE #{code}: #{created.to_json[0, 400]}"
  end
end

if sub && sub.dig("attributes", "state") != "WAITING_FOR_REVIEW"
  _code, items = request(:get, "/v1/reviewSubmissions/#{sub['id']}/items")
  unless (items["data"] || []).any?
    code, _ = request(:post, "/v1/reviewSubmissionItems", body: {
      data: {
        type: "reviewSubmissionItems",
        relationships: {
          reviewSubmission: { data: { type: "reviewSubmissions", id: sub["id"] } },
          appStoreVersion: { data: { type: "appStoreVersions", id: version_id } }
        }
      }
    })
    puts "REVIEW_ITEM #{code}"
  end
  code, submitted = request(:patch, "/v1/reviewSubmissions/#{sub['id']}", body: {
    data: { type: "reviewSubmissions", id: sub["id"], attributes: { submitted: true } }
  })
  puts "REVIEW_SUBMIT #{code} state=#{submitted.dig('data', 'attributes', 'state')}"
else
  puts "REVIEW already #{sub && sub.dig('attributes', 'state')}"
end

puts "DONE_FINISH"
