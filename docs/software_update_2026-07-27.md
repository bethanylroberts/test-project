---
title: "NARWC Database — Update Since July 19"
author: "Russell Shomberg"
date: "July 27, 2026"
---

## What's changed

Since the July 19 walkthrough:

- **Five new data sources are wired up**: CCS aerial, CCS vessel, CCS opportunistic
  sightings, NEAQ vessel, and NEAQ aerial surveys can now all be run through the
  system.
- **One process now, not two.** Importing historical data and importing new surveys
  used to be separate systems; they're now the same steps. Nothing changes in how
  you use it day to day.
- **Fewer false-alarm errors.** Two validation quirks were fixed — species codes
  now auto-fill their taxonomic category where possible, and stray GPS
  button-presses with no species logged are no longer flagged as "missing species."
- **Folder layout cleanup.** The `data` folder was reorganized for consistency.
  This is why you'll need to run the one-time script below.

**Three open questions for you/Bob**, no rush, not blocking anything:

1. **Tow Boat US(A) charter platform code (CCS).** The cover sheet for
   `2023 Vessel/TB032223.csv` (paired with the "Habitat 2023 Season" cover sheet —
   there's no data file under that name) lists three possible codes: `107`
   (R/V Shearwater), `583` (merchant vessel), or `573` (towboat/similar). Which one
   actually applies?
2. **NEA vs. CWI as the data source.** Every Bay of Fundy (`Fundy*`) and Gulf of
   St. Lawrence (`GSL*`) file from the NEAQ & CWI vessel program currently reads
   DDSOURCE=`NEA`, even though the data was physically collected by CWI (Canadian
   Whale Institute) as part of that joint program. A `CWI` code already exists in
   the lookup table but isn't used anywhere in these files. Is `NEA` intentional
   (NEAQ as the data-submission steward for the joint program), or should some/all
   of these be `CWI` instead?
3. **Two boats sharing one platform code.** Fundy's "Scratcher" and GSL's "FRC
   Charlie" — two different small boats — are both currently coded PLATFORM=`572`,
   which is actually the lookup table's entry for the unrelated "Campobello Whale
   Rescue Boat." Neither has its own platform code. Should we add dedicated codes
   for them, or is `572` an acceptable generic stand-in for now?

Until these are resolved, files affected by them are deliberately left without a
DDSOURCE/PLATFORM default, so they'll show up flagged rather than silently guessed.
Full detail (if you want it) is in `PROJECT_STATUS.md` §8.7 and `CHANGELOG.md`.

## What to do

1. **Pull the latest `main` branch.**
2. **Open MATLAB and run `startup`**, as always.
3. **Run the one-time folder cleanup** (safe, reversible, fine to re-run):
   ```matlab
   reorganize_data_folder()              % dry run — shows what it would move, moves nothing
   reorganize_data_folder('Apply', true) % actually moves the files
   ```
   Nothing gets deleted — it only relocates files into the new folder names. Review
   the dry-run output first; if anything looks off, stop and ask.

That's it — your existing workflow is unchanged otherwise. The five new parsers are
just available next time files come in from those sources.

Please do this before you leave on August 1 if you get a chance, so everything's in
sync when you're back.
