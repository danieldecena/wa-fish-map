# Audit — 2026-09-21

## Executive Summary

Audit of `/Users/home/Developer/wa-fish-map` conducted on 2026-09-21. The codebase is a mature, production-ready Swift/SwiftUI MapKit application targeting iOS 18.0, currently at App Store release candidate stage (build 1.0 (6) submitted). Security posture is clean with zero hardcoded secrets and strict HTTPS. However, configuration and documentation suffer from notable drift: CI is completely absent (GitHub Actions removed due to billing blocks), no license file is present, linting/formatting is unenforced in repo config, and README/SETUP carry stale instructions, dead simulator names, and outdated feature descriptions.

## Blockers
*None for immediate local development.*

## Risks
- [ ] **No active CI pipeline** — GitHub Actions was disabled and `.github/workflows/ci.yml` deleted. PRs and branches cannot be automatically tested. Configure Xcode Cloud workflows before onboarding additional contributors or shipping further updates.
- [ ] **Stale test commands and simulator destinations in README, SETUP, and CLAUDE.md** — README and SETUP prescribe `name=iPhone 17`, while `CLAUDE.md` prescribes `name=iPhone`. Neither device exists on host toolchains running iPhone 18 simulator runtimes. Update documentation to mandate dynamic device resolution via `scripts/run_sim.sh`.
- [ ] **SETUP.md references deleted CI configuration** — Lines 38-39 point to `.github/workflows/ci.yml`, which was removed. Remove or update the reference.
- [ ] **README feature scope severely out of date** — README claims the app is a "Hybrid map centered on South Puget Sound". The application is fully statewide with 16 marine areas, rivers, USGS streamflow, NOAA tides, NDBC buoys, WeatherKit integration, and lake facts. Revise README to reflect true product scope.
- [ ] **Missing LICENSE file** — The repository has a public remote but contains no `LICENSE` file. Add an appropriate license.
- [ ] **Implicit Xcode 26 toolchain requirement in CLAUDE.md** — `CLAUDE.md` declares deployment target iOS 18.0, but omits that the build host MUST use Xcode 26+ (iOS 26 SDK) due to compile-time reference to `GlassCard.glassEffect`. Explicitly record the toolchain floor in `CLAUDE.md`.
- [ ] **Implicit streamflow, buoy, and weather architectures in CLAUDE.md** — Major subsystems (`RiverLoader`, `NDBCLoader`, `PlanWeather`, MPA layer logic) are documented only in `STATUS.md` decision logs, not in `CLAUDE.md`. Document their architectural contracts in `CLAUDE.md`.

## Notes
- **Top-level RESEARCH.md absent**: Research exists as six dated documents in `docs/research/`.
- **Incomplete repo-level .gitignore**: `.gitignore` lacks coverage for Python artifacts and `.cursor/`. These are currently filtered only by host `~/.gitignore_global`.
- **Unenforced linting and formatting**: No `.swiftlint.yml`, `.swift-format`, or `ruff.toml` exists in the repository.
- **Undocumented utility scripts**: `scripts/build_lakes.py`, `scripts/build_rivers.py`, `scripts/build_river_stats.py`, `scripts/build_web_data.py`, `scripts/testflight_internal.py`, and `scripts/app_store_screenshots.sh` lack documentation in README/SETUP.
- **Web demo footprint**: `site/data/` and `docs/web-demo-spec.md` exist in the main branch but are not mentioned in root project documentation.
- **Hardware test gating**: `testWindReadsARealValueOnDevice` must continue using `scripts/verify_weatherkit_device.sh` as Simulator WeatherKit provisioning is impossible.
