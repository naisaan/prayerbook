# Bahá’í Prayer Book

A prayer book for iPhone that reads like Apple Books: a real page curl, light and dark mode,
a choice of San Francisco, New York or Helvetica, and a drop cap on each prayer. Each section's
prayers go from shortest to longest, and the next prayer always starts on the next page.

The prayers come from the original [Prayer Book app](https://github.com/arashpayan/prayer-book)
by Arash Payan.

## Run it on your Mac (first time)

1. Install **Xcode** from the Mac App Store and open it once so it can finish installing.
2. Double-click **PrayerBook.xcodeproj** in this folder. Xcode opens the project.
3. In the left sidebar, click the blue **PrayerBook** icon at the very top. Then click
   **Signing & Capabilities** in the middle of the window.
4. Next to **Team**, pick your name (your Apple ID). If you don't see it, go to
   **Xcode → Settings → Accounts** and sign in first.
5. At the top of the window, click the device name and pick an iPhone simulator,
   for example **iPhone 17 Pro**, or your own iPhone if it's plugged in.
6. Press the **▶ Play** button (or **⌘R**). The app opens in the simulator.

### If something goes wrong

- **"Signing requires a development team"**: do step 4.
- **"Failed to register bundle identifier"**: on the same Signing screen, change the
  **Bundle Identifier** to something unique, like `com.yourname.prayerbook`.
- **Your iPhone says "Untrusted Developer"**: on the iPhone, open **Settings → General →
  VPN & Device Management**, tap your Apple ID, and tap **Trust**.
- **Red errors in Xcode**: copy the error text (or take a screenshot) and send it to Claude.

## How to use the app

- Swipe or tap near the edge of the page to turn it.
- Each section opens with its own title page.
- Tap the middle of the page to show the menu button and the "12 of 340" page count. Tap the button for Contents,
  Bookmarks & Recents, Search Book, Themes & Settings, Languages, Share and About.

## How the code is organized

| Folder | What's inside |
| --- | --- |
| `PrayerBook/App` | Where the app starts |
| `PrayerBook/Data` | Reading the prayer database, languages, bookmarks, recents and saved settings |
| `PrayerBook/Reader` | Pages, typography, the drop cap and the page curl |
| `PrayerBook/Menu` | The floating menu and its screens |
| `PrayerBook/Resources` | `pbdb.db`, the prayer database from the original app |

## License

This app is based on the [original Prayer Book app](https://github.com/arashpayan/prayer-book) by Arash Payan, which is licensed under the GPLv3 or later. This app is released under the same license: the GNU General Public License, version 3 or later. See [LICENSE](LICENSE).

Privacy Policy: [PRIVACY.md](PRIVACY.md)
