test_that("errors without a default.nix", {
  local_project(default_nix = FALSE)
  expect_error(use_repro_check(run = "Rscript analysis.R"), "default.nix")
})

test_that("errors on invalid run argument", {
  local_project()
  expect_error(use_repro_check(run = character(0)))
  expect_error(use_repro_check(run = 1))
})

test_that("writes a workflow with the run commands", {
  local_project()
  path <- expect_invisible(use_repro_check(
    run = c("Rscript analysis.R", "quarto render paper.qmd")))

  expect_identical(path, file.path(".github", "workflows", "repro-check.yml"))
  expect_true(file.exists(path))

  yml <- readLines(path)
  expect_true(any(grepl("nix-build", yml, fixed = TRUE)))
  expect_true(any(grepl(
    "nix-shell default.nix --run 'Rscript analysis.R'", yml, fixed = TRUE)))
  expect_true(any(grepl(
    "nix-shell default.nix --run 'quarto render paper.qmd'", yml, fixed = TRUE)))
  # no leftover template placeholders
  expect_false(any(grepl("{{", yml, fixed = TRUE)))
})

test_that("default schedule is monthly; schedule = NULL drops the cron", {
  local_project()
  path <- use_repro_check(run = "Rscript analysis.R")
  expect_true(any(grepl("cron: '0 8 1 * *'", readLines(path), fixed = TRUE)))

  path <- use_repro_check(run = "Rscript analysis.R", schedule = NULL)
  yml <- readLines(path)
  expect_false(any(grepl("schedule:", yml, fixed = TRUE)))
  expect_false(any(grepl("cron", yml, fixed = TRUE)))
})

test_that("without outputs, no compare script or step is written", {
  local_project()
  path <- use_repro_check(run = "Rscript analysis.R")
  expect_false(file.exists(file.path("tools", "repro-compare.R")))
  expect_false(any(grepl("repro-compare", readLines(path), fixed = TRUE)))
})

test_that("outputs adds the compare script and step", {
  local_project()
  path <- use_repro_check(run = "Rscript analysis.R",
                          outputs = c("results", "data/summary.csv"))

  expect_true(file.exists(file.path("tools", "repro-compare.R")))
  yml <- readLines(path)
  compare <- grep("repro-compare.R", yml, fixed = TRUE, value = TRUE)
  expect_length(compare, 1)
  expect_match(compare, "results data/summary.csv", fixed = TRUE)
  expect_false(grepl("--tolerance", compare, fixed = TRUE))
})

test_that("tolerance is passed through to the compare step", {
  local_project()
  path <- use_repro_check(run = "Rscript analysis.R",
                          outputs = "results", tolerance = 1e-8)
  compare <- grep("repro-compare.R", readLines(path), fixed = TRUE, value = TRUE)
  expect_match(compare, "--tolerance 1e-08", fixed = TRUE)
})

test_that("workflow file name is configurable", {
  local_project()
  path <- use_repro_check(run = "Rscript analysis.R", workflow = "nightly.yml")
  expect_identical(path, file.path(".github", "workflows", "nightly.yml"))
  expect_true(file.exists(path))
})
