# rixcheck <img src="man/figures/logo.svg" align="right" height="139" alt="rixcheck hex sticker"/>

Continuous reproducibility checks for Nix-pinned R projects.

A project whose computational environment is described by a `default.nix`
(for example one generated with [rix](https://docs.ropensci.org/rix/)) makes
a strong promise: the environment can be rebuilt from its description alone,
years later, on any Linux machine. **rixcheck turns that promise into a
routinely tested fact.** It scaffolds a GitHub Actions workflow (and,
optionally, a Dockerfile) that:

1. rebuilds the pinned environment from the committed `default.nix`,
2. re-runs the project's analysis and/or renders its manuscript inside it,
3. optionally compares the freshly produced outputs against the versions
   committed to the repository.

Step 3 upgrades the check's claim from *"this project is executable"* to
*"this project still produces its published numbers, on Linux, from its
recipe."*

## Usage

In a project that already has a `default.nix`:

```r
# Render check only: does the environment build and the manuscript render?
rixcheck::use_repro_check(
  run = "quarto render Manuscript/article.qmd"
)

# Full check: re-run the simulation and verify committed results reproduce
rixcheck::use_repro_check(
  run = c("Rscript Simulation/06_run_all.R",
          "quarto render Manuscript/article.qmd"),
  outputs = "Simulation/results"
)

# A Dockerfile wrapping the same environment, for users without Nix
rixcheck::use_repro_dockerfile(
  run = "quarto render Manuscript/article.qmd"
)
```

Commit the generated files and push. The check runs on every push, on
demand, and (by default) monthly, so the project learns that its recipe has
decayed before a reader does.

## Design notes

- **rixcheck requires an existing `default.nix` and never generates one.**
  rix defines the environment; rixcheck proves it still works.
- **Comparisons are bitwise by default.** On a fixed platform (the CI's
  x86-64 Linux) a pinned environment reproduces results to the bit; treat
  that as the expectation, and reserve `tolerance =` for outputs of
  genuinely nondeterministic steps (multithreaded BLAS, parallel RNG).
- **Point `outputs` at data files (`.rds`, `.csv`), not rendered PDF/HTML.**
  Rendered documents embed dates and are never bitwise stable; the numbers
  behind them are the thing to check.
- **The platform of record is Linux.** Results produced on macOS may differ
  from the CI's in low-order bits (and, for iterative approximate
  algorithms, beyond them); commit outputs produced by the Linux
  environment where exactness matters.
