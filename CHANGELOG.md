# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-04-11

### Added
- UTF-8 BOM support via `bom: true` option for Excel-compatible output
- Custom output encoding via `encoding:` option

### Fixed
- Bug report template now requires Ruby version and gem version fields
- Feature request template now includes "Alternatives considered" field

## [0.4.0] - 2026-04-10

### Added
- `Builder#footer(&block)` appends a computed summary row after all data rows
- `Builder#limit(n)` caps output to N rows
- `Builder#offset(n)` skips the first N filtered/sorted records

## [0.3.0] - 2026-04-09

### Added
- Record sorting via `sort_by` DSL method with `:asc`/`:desc` direction support

## [0.2.0] - 2026-04-03

### Added
- Custom CSV delimiters via `delimiter:` option
- Custom quote character via `quote_char:` option
- Column header aliasing via `header:` option on columns
- Record filtering via `filter`
- Auto-incrementing row numbers via `row_number`
- Streaming output via `to_io`

## [0.1.5] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.1.4] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.1.3] - 2026-03-24

### Fixed
- Remove inline comments from Development section to match template

## [0.1.2] - 2026-03-22

### Changed
- Expanded test coverage to 30+ examples covering edge cases, error paths, and boundary conditions

## [0.1.1] - 2026-03-22

### Changed
- Version bump for republishing

## [0.1.0] - 2026-03-22

### Added
- Initial release
- Declarative column definition DSL
- Custom transform blocks for computed columns
- CSV string generation via `to_csv`
- File output via `to_file`
- Support for hash records with symbol and string keys
- Proper CSV escaping for values with commas and quotes

[0.5.0]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.5.0
[0.4.0]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.4.0
[0.3.0]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.3.0
[0.2.0]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.2.0
[0.1.5]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.1.5
[0.1.4]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.1.4
[0.1.3]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.1.3
[0.1.2]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.1.2
[0.1.1]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.1.1
[0.1.0]: https://github.com/philiprehberger/rb-csv-builder/releases/tag/v0.1.0
