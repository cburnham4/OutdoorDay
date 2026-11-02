# Outdoor Day — ship status

## Done

- SwiftUI MVP (`us.letshang.outdoor-day`): Go / Caution / Stay from Open-Meteo UV (day max) + pollen + US AQI
- Ads (AdMob test units) + StoreKit 2 `us.letshang.outdoor_day.remove_ads`
- App icon, privacy manifest, listing copy, GitHub Pages privacy/support
- Bundle ID + **App Store provisioning profile** on Apple Developer
- Simulator screenshots in `fastlane/screenshots/en-US/`
- **Release archive + IPA export succeeded** (`build/OutdoorDay.ipa` locally)
- Repo: https://github.com/cburnham4/OutdoorDay
- Privacy: https://cburnham4.github.io/OutdoorDay/privacy.html

## One blocker left (cannot automate)

**Create the App Store Connect app** in the browser (API forbids `apps` CREATE; upload fails with “Cannot determine the Apple ID from Bundle ID”):

1. Open https://appstoreconnect.apple.com/apps → **+** → New App  
2. Platforms: iOS · Name: **Outdoor Day** · Bundle ID: **us.letshang.outdoor-day** · SKU: `outdoor-day-001` · Access: Full  
3. Reply here — we will upload the IPA, attach screenshots/metadata, create IAP, and submit.

Optional in parallel: AdMob app under `ca-app-pub-8223005482588566` and paste IDs into `AdConfig.swift` / `Info.plist`.
