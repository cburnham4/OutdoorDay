# Human step: create Outdoor Day in App Store Connect

API keys cannot create apps (`apps` CREATE → 403). Browser automation has no valid Apple session.

Quick open: `bash scripts/open_asc_create.sh`

## Create app (required)

1. Sign in at https://appstoreconnect.apple.com/apps
2. **+** → New App
3. Platforms: **iOS**
4. Name: **Outdoor Day**
5. Primary Language: English (U.S.)
6. Bundle ID: **us.letshang.outdoor-day** (already registered)
7. SKU: **outdoor-day-001**
8. User Access: Full Access

After save, `asc_wait_and_ship` (or `bash scripts/asc_ship_all.sh`) uploads IPA, listing, IAP ($2.99), screenshots, and submits.

## App Privacy nutrition label (required for submit; not in public API)

App → App Privacy → Get Started / Edit:

- **Data Used to Track You:** Yes (AdMob)
- **Location → Precise Location:** App Functionality, not linked, not tracking
- **Identifiers → Device ID:** Third-Party Advertising, not linked, used for tracking
- **Usage Data → Product Interaction:** Third-Party Advertising + Analytics, not linked, used for tracking

Source draft: `fastlane/app_privacy.json`

## After create (first revenue)

IAP (`us.letshang.outdoor_day.remove_ads`, $2.99) is created/submitted by `asc_finish.rb` automatically — that path can earn without AdMob.

For ad revenue, create an AdMob iOS app + banner under publisher `ca-app-pub-8223005482588566`, then set in `OutdoorDay/Info.plist` (no code change needed):

- `GADApplicationIdentifier` = AdMob App ID (`…~…`)
- `GADBannerAdUnitID` = Banner unit ID (`…/…`)

Rebuild/export IPA and upload a follow-up build.

## Alternative: agent-assisted create (needs your 2FA code)

If you can paste a 6-digit Apple 2FA code in chat, the agent can run:

```bash
cd "/Users/carlburnham/Documents/coding/Ios Projects/OutdoorDay"
SPACESHIP_2FA_SMS_DEFAULT_PHONE_NUMBER="+1 (503) 929-7690" \
SPACESHIP_2FA_CODE=123456 \
bundle exec ruby scripts/asc_create_interactive.rb
```

Then wait-and-ship / `bash scripts/asc_ship_all.sh` continues automatically.
