# Outdoor Day — ship status

## Done

- SwiftUI MVP (`us.letshang.outdoor-day`): Go / Caution / Stay from UV + pollen + US AQI
- US pollen soft-fallback via Social Pollen Count when Open-Meteo species pollen is empty
- Ads (AdMob test units) + StoreKit 2 `us.letshang.outdoor_day.remove_ads`
- App icon, privacy manifest, listing copy, GitHub Pages privacy/support
- Bundle ID + App Store provisioning profile
- Screenshots in `fastlane/screenshots/en-US/` (6.5 / 6.7 / 6.9)
- Signed IPA: `build/OutdoorDay.ipa`
- Ship helpers:
  - `ruby scripts/asc_ship.rb` — IPA + listing metadata
  - `ruby scripts/asc_finish.rb` — IAP, age rating, screenshots, attach build, submit
- Repo: https://github.com/cburnham4/OutdoorDay

## One blocker (cannot automate)

Apple’s App Store Connect API **forbids creating apps** (`apps` CREATE → 403).

1. Open https://appstoreconnect.apple.com/apps → **+** → New App
2. iOS · Name **Outdoor Day** · Bundle ID **us.letshang.outdoor-day** · SKU `outdoor-day-001`
3. Reply here (or wait — we poll) and we run `asc_ship.rb` then `asc_finish.rb`.
