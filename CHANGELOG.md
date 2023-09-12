# Changelog

## [1.1.0] - 2023-09-12

### Added

- Changelog.
- Environmental variable file (.env) support.
- Gitignore paths.
- Program installation and configuration checks at beginning of script.
- Zenodo DOI badge to README.
- Zenodo metadata file.

### Changed

- Configuration comments so that they are in Sample.env instead of NewberryLoc.sh.
- Edge_ID to be integer with first 5 digits representing lowest FIPS code associated with way in 2000, followed by a 4-digit sequence sorted by location. Ways entirely outside of United States use FIPS 0.
- Insert order in certain topology SQL queries.
- Script may reference already-downloaded file.
- Script output targets to output folder, without creating ZIP.
- Stylistic and minor changes to README.
- Tabs to spaces in SQL file.

### Fixed

- Erroneous line break in output_counties_metadata.csv from full_name field in us_histcounties table.
- Linting errors in README.
- Pseudo-nodes in ways.

## [1.0.0] - 2022-09-15

### Added

- Public release of the Atlas of Historical County Boundaries: Conversion to Topology repository.

[1.1.0]: https://github.com/markconnellypro/ahcbp-topology/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/markconnellypro/ahcbp-topology/releases/tag/v1.0.0
