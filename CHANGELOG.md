# Changelog
All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- `detect_answering_machine` method with its `amd` alias

### Changed
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
