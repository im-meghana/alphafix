<div align="center">

<img src="assets/logo.png" alt="AlphaFix" width="90" height="90" />

<h1>AlphaFix</h1>

<p>Repair video metadata lost during re-encoding - dates, GPS, camera info, all fixed in seconds.</p>

<p>
  <img src="https://img.shields.io/badge/macOS-000000?style=flat-square&logo=apple&logoColor=white" alt="macOS" />
  <img src="https://img.shields.io/badge/Windows-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows" />
  <img src="https://img.shields.io/badge/Linux-E95420?style=flat-square&logo=linux&logoColor=white" alt="Linux" />
  <img src="https://img.shields.io/badge/Flutter-54C5F8?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
</p>

<p>
  <img src="https://img.shields.io/badge/version-1.0.0-FF6B35?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/license-MIT-4CAF50?style=flat-square" alt="License" />
  <img src="https://img.shields.io/badge/powered%20by-ExifTool-3A7BD5?style=flat-square" alt="ExifTool" />
  <img src="https://komarev.com/ghpvc/?username=im-meghana&repo=alphafix&style=flat-square&color=555555&label=views" alt="Views" />
</p>

<br/>

<p>
  <a href="https://buymeacoffee.com/im-meghana"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?style=flat-square&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Coffee" /></a>
  <a href="https://ko-fi.com/im-meghana"><img src="https://img.shields.io/badge/Ko--fi-FF5E5B?style=flat-square&logo=ko-fi&logoColor=white" alt="Ko-fi" /></a>
  <a href="https://paypal.me/im-meghana"><img src="https://img.shields.io/badge/PayPal-003087?style=flat-square&logo=paypal&logoColor=white" alt="PayPal" /></a>
  <a href="https://im-meghana.github.io/alphafix"><img src="https://img.shields.io/badge/UPI-89C341?style=flat-square&logo=googlepay&logoColor=white" alt="UPI" /></a>
</p>

</div>

---

## The Problem

When you re-encode or compress a video from a camera, the metadata gets stripped. Cloud services like **Ente, Google Photos, and iCloud** then sort your videos by the wrong date, lose GPS location, or show no camera info at all.

AlphaFix fixes this using [ExifTool](https://exiftool.org/) under the hood.

---

## Screenshots

<img src="assets/macos_screenshot.png" alt="AlphaFix on macOS" width="100%" />

---

## Download

<table>
  <tr>
    <td align="center" width="200">
      <img src="https://img.shields.io/badge/macOS-000000?style=for-the-badge&logo=apple&logoColor=white" alt="macOS" /><br/><br/>
      <a href="https://github.com/im-meghana/alphafix/releases/download/v1.0.0/AlphaFix.1.0.0.dmg">
        <img src="https://img.shields.io/badge/Download-.dmg-FF6B35?style=flat-square" alt="Download dmg" />
      </a>
    </td>
    <td align="center" width="200">
      <img src="https://img.shields.io/badge/Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white" alt="Windows" /><br/><br/>
      <img src="https://img.shields.io/badge/Coming-Soon-555555?style=flat-square" alt="Coming soon" />
    </td>
    <td align="center" width="200">
      <img src="https://img.shields.io/badge/Linux-E95420?style=for-the-badge&logo=linux&logoColor=white" alt="Linux" /><br/><br/>
      <img src="https://img.shields.io/badge/Coming-Soon-555555?style=flat-square" alt="Coming soon" />
    </td>
  </tr>
</table>

### macOS Installation

> AlphaFix is not notarized with Apple, so macOS Gatekeeper will block it on first launch.

1. Open the `.dmg` and drag **AlphaFix.app** into your `/Applications` folder
2. Open Terminal and run:

```bash
xattr -dr com.apple.quarantine /Applications/AlphaFix.app
```

3. Launch AlphaFix normally from Launchpad or Finder

> The `xattr` command removes the quarantine flag - it does not disable Gatekeeper system-wide.

---

## Features

<table>
  <tr>
    <td><b>Full Metadata Transfer</b></td>
    <td>Copy date, GPS, camera model, make and lens from original to re-encoded file</td>
  </tr>
  <tr>
    <td><b>UTC Timestamp Fix</b></td>
    <td>Fix wrong dates in Ente, Google Photos, iCloud without touching a second file</td>
  </tr>
  <tr>
    <td><b>Batch Mode</b></td>
    <td>Process a whole folder at once - files matched by filename, any extension</td>
  </tr>
  <tr>
    <td><b>Auto Rename</b></td>
    <td>Rename output to <code>YYYY-MM-DD_HH-MM-SS - cameraname.ext</code> after fixing</td>
  </tr>
  <tr>
    <td><b>Drag &amp; Drop</b></td>
    <td>Drop files or folders straight onto the input areas</td>
  </tr>
  <tr>
    <td><b>Live Console</b></td>
    <td>See exactly what ExifTool is doing in real time</td>
  </tr>
  <tr>
    <td><b>Cross-Platform</b></td>
    <td>macOS, Windows and Linux</td>
  </tr>
</table>

---

## Prerequisites

AlphaFix requires **ExifTool** to be installed on your system.

<details>
<summary><b>macOS</b></summary>
<br/>

```bash
brew install exiftool
```

</details>

<details>
<summary><b>Windows</b></summary>
<br/>

**winget (recommended)**
```powershell
winget install -e --id OliverBetz.ExifTool
```

**Chocolatey**
```powershell
choco install exiftool
```

**Scoop**
```powershell
scoop install exiftool
```

**Manual**
1. Download from [exiftool.org](https://exiftool.org/)
2. Rename `exiftool(-k).exe` to `exiftool.exe`
3. Move to `C:\Windows\`

</details>

<details>
<summary><b>Linux</b></summary>
<br/>

**Ubuntu / Debian**
```bash
sudo apt install libimage-exiftool-perl
```

**Fedora / RHEL**
```bash
sudo dnf install perl-Image-ExifTool
```

**Arch**
```bash
sudo pacman -S perl-image-exiftool
```

**Snap**
```bash
sudo snap install exiftool
```

</details>

---

## How to Use

### Single - transfer metadata after re-encoding

1. Drop your **original camera file** into the **INPUT** slot
2. Drop your **re-encoded file** into the **OUTPUT** slot
3. Optionally enable **Rename after fixing** and enter your camera name
4. Click **Fix Metadata**

### Single - fix UTC timestamp only

Use this when your video shows the **wrong date in Ente, Google Photos or iCloud** but looks fine locally. This is a common Sony camera issue - the local time tag is correct but cloud services read the UTC-based QuickTime tag.

1. Select the **same file** for both INPUT and OUTPUT
2. AlphaFix shows a **UTC-fix mode** banner
3. Click **Fix Metadata** - rewrites the QuickTime UTC tag in-place, no second file needed

### Batch - process a whole folder

> Files are matched by base filename only. The extension can differ - `A001.MP4` will match `A001.mov`.

1. Switch to the **BATCH** tab
2. Select your **Originals folder** and **Encoded folder**
3. Optionally select an **Output folder** - leave empty to fix in-place
4. Click **Run Batch Fix**

---

## Build from Source

**Requirements:** Flutter 3.0+, Dart 3.0+, ExifTool

```bash
git clone https://github.com/im-meghana/alphafix.git
cd alphafix
flutter pub get

# Run
flutter run -d macos
flutter run -d windows
flutter run -d linux

# Release build
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

---

## Tech Stack

<table>
  <tr>
    <td><img src="https://img.shields.io/badge/Flutter-54C5F8?style=flat-square&logo=flutter&logoColor=white" /></td>
    <td><a href="https://flutter.dev/">Flutter</a></td>
    <td>UI framework</td>
  </tr>
  <tr>
    <td><img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" /></td>
    <td><a href="https://dart.dev/">Dart</a></td>
    <td>Language</td>
  </tr>
  <tr>
    <td><img src="https://img.shields.io/badge/ExifTool-3A7BD5?style=flat-square" /></td>
    <td><a href="https://exiftool.org/">ExifTool</a></td>
    <td>Metadata engine by Phil Harvey</td>
  </tr>
  <tr>
    <td><img src="https://img.shields.io/badge/file__picker-555555?style=flat-square" /></td>
    <td><code>file_picker</code></td>
    <td>Native file picker dialog</td>
  </tr>
  <tr>
    <td><img src="https://img.shields.io/badge/desktop__drop-555555?style=flat-square" /></td>
    <td><code>desktop_drop</code></td>
    <td>Drag and drop support</td>
  </tr>
  <tr>
    <td><img src="https://img.shields.io/badge/flutter__svg-555555?style=flat-square" /></td>
    <td><code>flutter_svg</code></td>
    <td>SVG rendering</td>
  </tr>
  <tr>
    <td><img src="https://img.shields.io/badge/path-555555?style=flat-square" /></td>
    <td><code>path</code></td>
    <td>Cross-platform path handling</td>
  </tr>
</table>

---

## Contributing

Pull requests are welcome. For major changes, open an issue first.

1. Fork the repo
2. Create your branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

---

## License

[MIT](LICENSE)

---

<div align="center">

[![Star History Chart](https://api.star-history.com/svg?repos=im-meghana/alphafix&type=Date)](https://star-history.com/#im-meghana/alphafix&Date)

<br/>

Made by [Meghana](https://github.com/im-meghana) · Powered by [ExifTool](https://exiftool.org/)

</div>
