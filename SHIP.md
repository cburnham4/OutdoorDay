# Outdoor Day — ship status

## Done

- SwiftUI MVP (`us.letshang.outdoor-day`): Go / Caution / Stay from UV + pollen + US AQI
- US pollen soft-fallback via Social Pollen Count when Open-Meteo species pollen is empty
- Ads (AdMob test units) + StoreKit 2 `us.letshang.outdoor_day.remove_ads`
- ATT before `MobileAds.start`; PrivacyInfo tracking + Device ID; `ITSAppUsesNonExemptEncryption=false`
- AdMob SKAdNetwork list (50 IDs); categories Weather + Health; copyright + marketing URL metadata
- Ship scripts set IAP `$2.99` price schedule + submit IAP on finish
- App icon, privacy manifest, listing copy, GitHub Pages privacy/support (live)
- Bundle ID + App Store provisioning profile (`Outdoor Day App Store 202611012142`)
- Screenshots in `fastlane/screenshots/en-US/` (6.5 / 6.7 / 6.9)
- Signed IPA: `build/OutdoorDay.ipa` (ATT + SKAd rebuild 2026-11-02 12:20 EST)
- Ship helpers:
  - `bash scripts/asc_ship_all.sh` — ship + finish in one shot
  - `ruby scripts/asc_ship.rb` — IPA + listing metadata
  - `ruby scripts/asc_finish.rb` — IAP, age rating, screenshots, attach build, submit
- Repo: https://github.com/cburnham4/OutdoorDay

## One blocker (cannot automate)

Apple’s App Store Connect API **forbids creating apps** (`apps` CREATE → 403).

1. Open https://appstoreconnect.apple.com/apps → **+** → New App
2. iOS · Name **Outdoor Day** · Bundle ID **us.letshang.outdoor-day** · SKU `outdoor-day-001`
3. Reply here (or wait — we poll) and we run `asc_ship.rb` then `asc_finish.rb`.
