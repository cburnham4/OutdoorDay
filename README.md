# Outdoor Day

One-screen **UV / allergy / air-quality** planner: *Should I go outside today?*

## Stack

- SwiftUI, iOS 17+
- Open-Meteo air-quality + forecast APIs (no API key for MVP)
- Core Location
- Google Mobile Ads (banner; sample unit ID until production AdMob app is created)
- StoreKit 2 non-consumable `us.letshang.outdoor_day.remove_ads`

## Open

```bash
open "OutdoorDay.xcodeproj"
```

Select the **OutdoorDay** scheme. For IAP testing in Simulator, use `Configuration.storekit` (Scheme → Run → Options → StoreKit Configuration).

## Ship checklist

1. Replace AdMob app ID + banner unit in `Info.plist` / `AdBannerView.swift`
2. Create ASC app `us.letshang.outdoor-day` + IAP product
3. Add App Icon 1024×1024
4. Capture 6.7" screenshots
5. Archive & submit
