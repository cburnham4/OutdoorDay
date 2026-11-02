# Human step: create Outdoor Day in App Store Connect

API keys cannot create apps (`apps` CREATE → 403). Browser automation has no valid Apple session.

## Create app (required)

1. Sign in at https://appstoreconnect.apple.com/apps
2. **+** → New App
3. Platforms: **iOS**
4. Name: **Outdoor Day**
5. Primary Language: English (U.S.)
6. Bundle ID: **us.letshang.outdoor-day** (already registered)
7. SKU: **outdoor-day-001**
8. User Access: Full Access

After save, the hourly poll / `bash scripts/asc_ship_all.sh` uploads IPA, listing, IAP ($2.99), screenshots, and submits.

## App Privacy nutrition label (required for submit; not in public API)

App → App Privacy → Get Started / Edit:

- **Data Used to Track You:** Yes (AdMob)
- **Location → Precise Location:** App Functionality, not linked, not tracking
- **Identifiers → Device ID:** Third-Party Advertising, not linked, used for tracking
- **Usage Data → Product Interaction:** Third-Party Advertising + Analytics, not linked, used for tracking

Source draft: `fastlane/app_privacy.json`

## Optional for first revenue

Create AdMob iOS app + banner under publisher `ca-app-pub-8223005482588566`, then replace test IDs in `AdConfig.swift` / `Info.plist` and rebuild IPA.
