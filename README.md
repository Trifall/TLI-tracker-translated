# YiHuo ETor - English Translation

## 🌍 Translation Disclaimer

**This is NOT my original work.**

I have merely translated the user interface from Chinese to English to make this excellent Torchlight: Infinite tracking tool accessible to the international community.

All credit for the development, design, and functionality of this application belongs to the original creators of **易火-ETor (YiHuo ETor)**.

---

## 📦 What This Is

YiHuo ETor is a comprehensive tracking and analysis tool for **Torchlight: Infinite** that helps players:
- Monitor farming efficiency in real-time
- Track item pickups and loot history
- Analyze profit per minute and cost effectiveness
- Record detailed statistics across multiple maps and sessions
- Optimize farming strategies with data-driven insights

---

## 📥 Installation

1. Go to the [Releases](https://github.com/Giboork/TLI-tracker-translated/releases) page
2. Download the latest `TLI-tracker-translated.zip` file
3. Extract the ZIP file to a folder of your choice
4. Run `易火-ETor.exe` to start the application

That's it! The app will run in English.

### Linux Compatibility

This repository is an unpacked Windows Electron release, not the original full source tree. The app logic is stored in `resources/app.asar`, which can run on Linux when paired with a Linux Electron runtime.

For a quick Linux run from this checkout:

```bash
bash scripts/run-linux.sh
```

To build a reusable Linux folder:

```bash
bash scripts/build-linux-unpacked.sh
./dist/linux-unpacked/run.sh
```

The Linux build uses Electron `32.0.0` by default. Override it with `ELECTRON_VERSION=32.0.0` if needed.

The tracker reads the game's log through the in-app file picker. On Linux, select the `UE_game.log` file from wherever Torchlight: Infinite stores it in your Steam/Proton prefix or native game directory.

---

## 🔧 What I Did

This English version includes:
- ✅ Fully translated user interface
- ✅ Translated system dialogs and notifications
- ✅ Pattern-based translation for dynamic content
- ✅ Localized category labels and item names
- ✅ Auto-updating translation system via AppData

**Translation by:** GIBOo_

---

## ⚠️ Important Notes

- This is an **unofficial translation** - not endorsed by the original developers
- If the translated version doesn't work correctly, please revert to the original Chinese version
- All feedback regarding core functionality should be directed to the original creators
- Translation issues can be reported, but I cannot fix bugs in the base application

---

## 🙏 Credits

All credit goes to the original YiHuo ETor development team for creating this powerful tool.

*This translation exists solely to help the global Torchlight: Infinite community.*

---

## 📄 License

The original application's license applies. This translation is provided as-is with no warranties.

If you're the original developer and want this translation removed or modified, please contact me.
