# fastlane-plugin-appshot

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-appshot)

A [_fastlane_](https://github.com/fastlane/fastlane) action that turns fastlane snapshot's raw captures into finished App Store screenshots with [appshot](https://github.com/jems19s/appshot-studio) — real device bezels, localized captions, generated backgrounds — and puts them where `deliver` uploads from.

```ruby
lane :screenshots do
  capture_screenshots(output_directory: "fastlane/raw_screenshots")
  appshot(raw_screenshots: "fastlane/raw_screenshots")
  upload_to_app_store(skip_binary_upload: true, skip_metadata: true)
end
```

For every locale the action:

1. copies snapshot's capture of each screen into the appshot studio, so every language gets its own app screens;
2. runs `appshot render`;
3. copies the framed PNGs into `fastlane/screenshots/<locale>/`, the folder `deliver` uploads.

## Setup

```bash
brew install jems19s/tap/appshot
fastlane add_plugin appshot
```

Then, once, create the appshot studio next to your `fastlane` folder — the device, captions, colors and layout of your screenshots. Copy one locale's captures into a folder under plain names (`map.png`, `place.png`, …) and run:

```bash
mkdir appshot && cd appshot
appshot init --name myapp --device "iPhone 17 Pro Max" --screenshots ../plain-captures \
  --locale en-US --locale de-DE \
  --caption 'The best cafés,\n*right around you*' --caption 'Know exactly\n*what to order*'
```

Translate the captions in `apps/myapp/captions/<locale>.json`, style it in `apps/myapp/config.json`, and commit the studio (add `devices/` and `output/` to its `.gitignore`). See the [appshot README](https://github.com/jems19s/appshot-studio#readme) for everything you can change, or let a coding agent do it with appshot's [skill](https://github.com/jems19s/appshot-studio#with-a-coding-agent).

### How captures are matched

fastlane snapshot saves `<simulator name>-<name>.png` in one folder per locale. A capture goes to the slot whose `screenshot` is `<name>.png`, so name your `snapshot("…")` calls after the studio's screenshots:

```swift
snapshot("map")    // fastlane/raw_screenshots/de-DE/iPhone 17 Pro Max-map.png → apps/myapp/assets/de-DE/map.png
```

If snapshot runs on several simulators, say which one appshot frames with `device: "iPhone 17 Pro Max"`. A locale with no captures keeps the screenshots already in the studio.

### Keep raw captures out of deliver's folder

snapshot writes to `fastlane/screenshots` by default — the folder `deliver` uploads. Point it somewhere else (`output_directory("./fastlane/raw_screenshots")` in the Snapfile, or the `capture_screenshots` option above), or `deliver` uploads raw and framed images side by side. The action refuses to read and write the same folder, and warns about any other PNGs it finds where it copies.

## Options

| Key | Default | Description |
| --- | --- | --- |
| `studio` | `appshot` | appshot studio: the folder holding `apps/`, `templates/` and `devices/` |
| `app` | the only app | app under `apps/` |
| `raw_screenshots` | | snapshot's `output_directory`. Leave it out to render the screenshots already in the studio |
| `device` | | simulator whose captures to use, when `raw_screenshots` holds several |
| `locales` | all the app's locales | locales to import and render |
| `output_directory` | `fastlane/screenshots` | framed PNGs go to `<output_directory>/<locale>/` |
| `appshot_path` | `appshot` | the appshot command |
| `chrome` | found automatically | Chrome or Chromium to render with |

Every option can also come from an environment variable: `APPSHOT_STUDIO`, `APPSHOT_APP`, `APPSHOT_RAW_SCREENSHOTS`, `APPSHOT_DEVICE`, `APPSHOT_LOCALES`, `APPSHOT_OUTPUT_DIRECTORY`, `APPSHOT_PATH`, `APPSHOT_CHROME`.

The action returns a hash of locale → paths of the copied screenshots.

## Development

```bash
bundle install
bundle exec rake    # tests and rubocop
```

The tests use a stand-in for the `appshot` binary, so they run without appshot or Chrome.

## License

MIT — see [LICENSE](LICENSE).
