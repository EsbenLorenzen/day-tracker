# Installing on the iPhone from Windows (Sideloadly)

Uses a free Apple ID (D04). The app has to be re-signed **every 7 days**.

## One-time setup

1. **iTunes and iCloud for Windows**: install the versions from apple.com, *not* the Microsoft Store versions. Sideloadly needs their drivers.
2. **Sideloadly**: download from <https://sideloadly.io> and install.
3. Connect the iPhone by USB, unlock it, and tap **Trust This Computer**.
4. **Developer Mode** on the iPhone: Settings → Privacy & Security → Developer Mode → On, then restart. It only appears after the first sideload attempt, so you may have to come back to this step.

## Each install

1. Open the latest successful run on GitHub: **Actions → iOS build**.
2. Download the artifact `DayTracker-unsigned-<n>`. It comes as a `.zip`; extract it to get `DayTracker-unsigned.ipa`.
3. Drag the `.ipa` into Sideloadly, check that your iPhone is selected, enter your Apple ID, and click **Start**.
   - Leave the bundle ID unchanged (`com.esbenlorenzen.daytracker`). That way, re-installing keeps your data.
   - Some people use a secondary Apple ID for sideloading. Optional.
4. First time only: on the iPhone, go to Settings → General → VPN & Device Management, tap your Apple ID under *Developer App*, and choose **Trust**.
5. Open DayTracker. The build number at the bottom should match the GitHub run number.

## Every 7 days

Repeat "Each install" with the same or a newer IPA. Don't delete the app first, or its data is lost.
Sideloadly can also auto-refresh over Wi-Fi while the PC is on (see its settings).

## Phase 0 check

- [ ] App launches and shows the green seal plus the build number
- [ ] "Send test notification in 10 s" → allow notifications → a banner arrives (also with the phone locked)
