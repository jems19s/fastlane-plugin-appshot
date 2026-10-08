# Changelog

All notable changes to fastlane-plugin-appshot are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-10-08

### Fixed

- Screenshots of a size deliver can't upload, such as the iPhone Duo's 2853×2007 (App Store Connect takes those only through its new asset library), were copied into deliver's folder, where deliver cancels the whole screenshot upload over them. They now stay in the studio's `output/` folder, and the action says which sizes and where to find them. The check is deliver's own list of supported sizes, so it follows deliver when it learns new devices.

## [0.1.0] - 2026-10-08

### Added

- The `appshot` action. For every locale it copies fastlane snapshot's capture of each screen into an [appshot](https://github.com/jems19s/appshot-studio) studio (a capture named `<simulator>-<name>.png` goes to the slot whose screenshot is `<name>.png`), renders the framed, captioned screenshots with appshot, and copies them into `<output_directory>/<locale>/`, the folder deliver uploads.
- Options `studio`, `app`, `raw_screenshots`, `device`, `locales`, `output_directory`, `appshot_path` and `chrome`, each also settable through an `APPSHOT_*` environment variable.
- Safeguards: the action refuses to read raw captures from the folder deliver uploads, warns about other PNGs deliver would upload alongside the framed ones, asks for `device:` when captures from several simulators match, and explains how to install appshot when it is missing.
- Requires Ruby 3.1 or later, like current fastlane.

[0.1.1]: https://github.com/jems19s/fastlane-plugin-appshot/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jems19s/fastlane-plugin-appshot/releases/tag/v0.1.0
