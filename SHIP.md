# Outdoor Day — ship status

## Done

- SwiftUI MVP (`us.letshang.outdoor-day`): Go / Caution / Stay from UV + pollen + US AQI
- US pollen soft-fallback via Social Pollen Count when Open-Meteo species pollen is empty
- Ads (AdMob test units) + StoreKit 2 `us.letshang.outdoor_day.remove_ads`
- App icon, privacy manifest, listing copy, GitHub Pages privacy/support
- Bundle ID + App Store provisioning profile
- Screenshots in `fastlane/screenshots/en-US/`
- Signed IPA: `build/OutdoorDay.ipa` (rebuild anytime; export uses installed profile)
- Ship helper: `ruby scripts/asc_ship.rb` (uploads IPA + metadata once ASC app exists)
- Repo: https://github.com/cburnham4/OutdoorDay

## One blocker (cannot automate)

Apple’s App Store Connect API **forbids creating apps** (`apps` CREATE → 403). Browser ASC login needs your Apple ID.

1. Open https://appstoreconnect.apple.com/apps → **+** → New App  
2. iOS · Name **Outdoor Day** · Bundle ID **us.letshang.outdoor-day** · SKU `outdoor-day-001`  
3. Reply here (or wait — we poll) and we run `scripts/asc_ship.rb`, attach screenshots/IAP, and submit.
