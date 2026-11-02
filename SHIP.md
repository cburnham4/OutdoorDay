# Outdoor Day — ship status

## Done

- SwiftUI MVP app (`us.letshang.outdoor-day`): one-screen Go / Caution / Stay verdict from Open-Meteo UV + pollen + US AQI
- Location permission + Core Location
- AdMob banner scaffolding (`AdConfig` — still on Google **test** units until Outdoor Day AdMob app is created)
- StoreKit 2 non-consumable `us.letshang.outdoor_day.remove_ads` + `Configuration.storekit`
- App icon, privacy manifest, App Store metadata copy
- Unit tests for verdict engine — **TEST SUCCEEDED**
- Simulator build — **BUILD SUCCEEDED**
- GitHub: https://github.com/cburnham4/OutdoorDay
- Privacy / support URLs live:
  - https://cburnham4.github.io/OutdoorDay/privacy.html
  - https://cburnham4.github.io/OutdoorDay/support.html
- Apple Developer **bundle ID** created: `us.letshang.outdoor-day` (with In-App Purchase capability)

## Also ready locally

- Release **xcarchive** builds (`/tmp/OutdoorDay.xcarchive` on the build machine)
- App Store screenshots in `fastlane/screenshots/en-US/` (6.5" + 6.7")

## Blocked (needs you — ~10 minutes)

1. **Sign into Xcode** with `cburnham@letshang.us` (export failed: “No Accounts” / no profiles for the new bundle).
2. **Create the App Store Connect app** for bundle `us.letshang.outdoor-day`  
   ASC API key cannot CREATE apps. [App Store Connect](https://appstoreconnect.apple.com/apps) → **+** → New App → iOS → Outdoor Day → bundle `us.letshang.outdoor-day`.
3. **Create IAP** “Outdoor Day Plus” product ID `us.letshang.outdoor_day.remove_ads` (Non-Consumable, ~$2.99).
4. **AdMob**: create Outdoor Day app under publisher `ca-app-pub-8223005482588566`; put real App ID in `Info.plist` and banner unit in `AdConfig.swift` (currently Google test units).
5. After 1–2: reply here and we export/upload, attach screenshots + metadata, submit.

## Local open

```bash
open "/Users/carlburnham/Documents/coding/Ios Projects/OutdoorDay/OutdoorDay.xcodeproj"
```
