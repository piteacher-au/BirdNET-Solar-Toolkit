# Changelog

All notable changes to this project will be documented in this file.

The format is inspired by *Keep a Changelog* and the project follows
Semantic Versioning where practical.

------------------------------------------------------------------------

## \[0.1.0\] - 2026-07-20

### Added

-   Initial GitHub repository.
-   Professional project README.
-   `battery_shutdown.py` with:
    -   Scheduled shutdown at 6:00 PM.
    -   Emergency low-battery shutdown.
    -   RTC wake scheduling for 6:00 AM.
    -   RTC wake verification before shutdown.
    -   Safe filesystem synchronisation.
-   Dependency documentation (`docs/Dependencies.md`).
-   Initial project folder structure:
    -   `docs/`
    -   `scripts/`
    -   `images/`

### Planned

-   Deployment guide.
-   Hardware guide.
-   Solar configuration guide.
-   RTC configuration guide.
-   One-command installer (`install.sh`).
-   Automated EEPROM configuration.
-   RTC self-test utility.
-   BirdNET health check.
-   UPS diagnostics.
-   Automated deployment verification.

------------------------------------------------------------------------

## Versioning

Future releases will use semantic version numbers:

-   **0.x** -- Development releases
-   **1.0.0** -- First stable public release
-   **1.x** -- Stable feature releases
-   **2.x** -- Major feature revisions
