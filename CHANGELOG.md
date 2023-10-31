# Changelog
All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

 ## [Unreleased]

## [2.5.0] - 2023-10-26
### Added
- Add Middleware `SignalwireWebhookAuthentication`

## [2.4.0] - 2023-10-13
### Added
- Add Webhook `ValidateRequest`

## [2.3.4] - 2020-09-09
### Fixed
- Correctly ignore non-call events and clear handlers on call end
- Async method arguments fixed
- Fix ping race condition

## [2.3.3] - 2020-03-09
### Fixed
- `record` correctly set up for terminators now.
- Make AMD more usable and less complex.
- AMD now returns immediately in `wait_for_beep` mode if it detects a human.
-  Relax `gemspec` dependencies.

## [2.3.2] - 2020-01-29
### Fixed
- Correctly return AMD result in Relay.

## [2.3.1] - 2019-12-20
### Changed
- Keepalive now uses `blade.ping`.

## [2.3.0] - 2019-10-22
### Added
- Add `pause` and `resume` on `PlayAction`.
- Add `volume` optional parameter to `play` and `prompt` methods
- Add `volume` method to `Play` and `Prompt` components
- Add `play_ringtone` and `play_ringtone!` for ringback.
- Add `prompt_ringtone` and `prompt_ringtone!` for ringback on a prompt.
- Added `ringback` parameter to the `connect` and `connect!` methods.

## [2.2.0] - 2019-09-09
### Added
- `detect_answering_machine` method with its `amd` alias

### Changed
- Flatten parameter structures for better readability
- Log all exceptions as errors by default.
- Deprecated `detect_human` and `detect_machine` methods in favor of `detect_answering_machine`

## [2.1.3] - 2019-08-20
### Fixed
- Restore the correct parameter for the REST client space URL
- Correctly handle reconnect on a server-side disconnect
- Fix REST pagination URL
### Changed
- SDK now uses `signalwire.receive` to set up contexts
- The `call.*` actions are now `calling.*`
- Support positional parameters in older methods

## [2.1.2] - 2019-08-01
### Fixed
- Fix CPU usage
- Set default log level to INFO.
- Fix incorrect names for messaging parameters.
- Fix an issue when creating new calls.

## [2.1.1] - 2019-08-01
### Fixed
- Correctly set `peer` on calls
### Changed
- Call `Consumer::teardown` on shutdown

## [2.1.0] - 2019-07-29
### Added
- Tap API for Relay
- `:task` broadcast from client
- `Relay::Task` and `on_task` handler for `Consumer`
- Fax API for Relay
- `Detect` API for Relay
- Messaging API for Relay
### Changed
- Changed `SIGNALWIRE_ACCOUNT` environment variable to `SIGNALWIRE_PROJECT_KEY` to match UI

## [2.0.0] - 2019-07-16
### Added
- Connection Retry upon disconnect.
### Changed
- Switch to using hostname only to specify URLs

## [2.0.0-rc.1] - 2019-07-15
### Added
- Released new Relay Client interface.

## [1.4.0] - 2019-04-12
### Added
- Add ability to specify domain via parameter
- Accept both `SIGNALWIRE_SPACE_URL` and `SIGNALWIRE_API_HOSTNAME` variables for configuration

## [1.3.0] - 2019-01-15
### Added
- Fax REST API support, better tests

## [1.2.0] - 2018-12-29
### Added
- LaML Fax support

## [1.0.0] - 2018-10-20
### Added
- First release!

<!---
### Added
### Changed
### Removed
### Fixed
### Security
-->
