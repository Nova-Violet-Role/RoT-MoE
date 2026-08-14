---
name: corpus
description: Check or refresh the shared Lean Theorem corpus from the RoT MoE repository
---

# `/corpus` — the shared proof corpus

The `Lean Theorem/` folder is the **shared corpus**: proofs about other people's
code, contributed by fork and pull request. It grows independently of the plugin
version, which is exactly why it is fetched rather than shipped — a new plugin
release for every contributed theorem would mean the version number was tracking
somebody else's proofs.

## What to do

Run the fetcher that ships with the plugin. Pick the arm for the platform:

```sh
./SETUP_CORPUS.sh --check          # report only, writes nothing
./SETUP_CORPUS.sh                  # detect, show what changes, ask
./SETUP_CORPUS.sh --yes            # non-interactive refresh
```

```powershell
.\SETUP_CORPUS.ps1 -Check
.\SETUP_CORPUS.ps1
.\SETUP_CORPUS.ps1 -Yes
```

## Exit codes — identical on both arms

| code | meaning |
|---:|---|
| `0` | the corpus is current, or the user declined — **nothing was written** |
| `2` | refusal: bad argument, no downloader, or the remote is unreachable |
| `3` | `--check` only: an update is available |
| `4` | `--check` only: the corpus is absent |
| `1` | a fetch was attempted and **failed** — the existing corpus is untouched |

## What it will not do

It will **never silently overwrite a modified corpus.** If any `.lean` file
changed after the last fetch, those paths are listed before anything happens and
you are asked. The previous corpus is moved aside as
`Lean Theorem.pre-fetch-<timestamp>.bak` rather than deleted, and a download that
arrives with **zero** `.lean` files is refused outright — that is an erasure, not
an update, and the copy on disk is kept.

## Reporting back

After running it, state plainly:

- how many subjects and modules are now on disk,
- the commit the corpus was fetched at,
- and whether anything was replaced.

If the fetch failed, say so with the exit code and **do not** claim the corpus
was updated. The user's existing corpus surviving a failed fetch is the designed
behaviour, not a fallback worth hiding.
