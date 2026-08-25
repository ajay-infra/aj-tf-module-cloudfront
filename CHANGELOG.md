# Changelog

All notable changes to this module are documented here. Format loosely follows [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Fixed
- `README.md`'s "Provider pins" table said Terraform `= 1.7.5` — `providers.tf` actually pins `= 1.10.5`, matching the platform-wide Terraform 1.10.5 migration already reflected everywhere else. Same stale-version pattern already found and fixed in `aj-tf-module-vpc`, `aj-tf-module-eks`, `aj-tf-module-aurora`, `aj-tf-module-valkey`, and `aj-tf-module-ecr`.
- `skills.md`'s "Stable ref" pointed at `github.com/ajaylakma/aj-tf-module-cloudfront?ref=cloudfront-01` — wrong org (real org is `ajay-infra`) and a branch that doesn't exist (only `main` — confirmed via `git branch -a`; no tags existed either, despite `README.md`'s own Usage example already correctly referencing `?ref=v0.1.0`, also nonexistent). Same pattern found repeatedly this project. Fixed both refs to `v1.0.0` and cut that tag (module was fully implemented with no prior release).
- `skills.md`'s "AWS tags applied" listed `Env`, `Team`, `ManagedBy`, `CostCenter`, `Model`, `Customer` — checked `locals.tf`: the real tag set is `Project`/`ManagedBy`/`Repository`/`Environment`/`Team`/`CostCenter` (from `locals.full_tags`) plus whatever's in `var.tags`. No `Env`, `Model`, or `Customer` tag exists anywhere in this module. Same pattern already found in several other modules this project.
- `skills.md`'s "Purpose" line described the blue/green mechanism as "traffic splitting" — grepped `main.tf` for any weighted-routing resource: none exists. The actual mechanism (confirmed against `CLAUDE.md`'s own "core invariant" section) is a hard CNAME flip — `active_color` moves the `active.<domain>` Route53 record from one ALB to the other in a single apply, all-or-nothing, with the CloudFront distribution itself never touched. Corrected the description so nobody expects gradual/weighted traffic shifting that was never built.

## [v1.0.0] - 2026-08-24

Initial release — CloudFront + WAFv2 (CRS, IP reputation, optional bot control, rate limit) + ACM wildcard cert + Route53 blue/green CNAME flip. Module was already fully implemented; this tag just formalizes the first stable release so `README.md`/`skills.md` have something real to pin to.
