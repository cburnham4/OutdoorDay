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

## Blocked (needs you in Apple / AdMob consoles)

1. **Create the App Store Connect app** for bundle `us.letshang.outdoor-day`  
   ASC API key cannot CREATE apps (GET/UPDATE only). Log into [App Store Connect](https://appstoreconnect.apple.com/apps) → **+** → New App → iOS → Outdoor Day → bundle `us.letshang.outdoor-day`.
2. **Create IAP** “Outdoor Day Plus” product ID `us.letshang.outdoor_day.remove_ads` (Non-Consumable, $2.99).
3. **AdMob**: create Outdoor Day app under publisher `ca-app-pub-8223005482588566`, put real App ID in `Info.plist` `GADApplicationIdentifier` and banner unit in `AdConfig.swift`.
4. Archive & upload first build, attach screenshots (6.7"), set age rating, submit.

## Local open

```bash
open "/Users/carlburnham/Documents/coding/Ios Projects/OutdoorDay/OutdoorDay.xcodeproj"
```
