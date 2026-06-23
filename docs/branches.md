# Branch Summary

The copied repository had several remote branches. No unresolved conflict
markers were found in the useful source files, but the branches contained
different parts of the course work.

| Branch | Commit | Main content |
| --- | --- | --- |
| `origin/main` | `d2dcd71` | README, introductory task and PDFs. |
| `origin/regs` | `845bfa1` | Register-file work. |
| `origin/cpu` | `86c2a53` | Processor building blocks and CPU integration. |
| `origin/cache` | `988c53b` | Cache and BRAM modules. |
| `origin/M_Extention` | `6e0d0f3` | M-extension branch after merging cache work. |
| `origin/merge_cache_m_extension` | `a57b83c` | Most complete combined branch: cache, M-extension and additional assembly examples. |
| `origin/Jennifer` | `235adf4` | Separate implementation path with exception and `mret` changes. |
| `origin/Mattes` | `c4e0d01` | Separate implementation path with introductory/task work. |

## Current Organization Choice

The organized working tree keeps `main` as the readable GitHub-facing branch and
adds the useful source content from `merge_cache_m_extension`. Local uncommitted
work from `../hardpracgit` was then overlaid on top, because it appears to be the
most recent personal work in the course folder.

This avoids a large manual merge across all historical branches while still
preserving the relevant project code in one clear structure.
