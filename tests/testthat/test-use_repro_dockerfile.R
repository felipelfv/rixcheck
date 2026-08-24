test_that("errors without a default.nix", {
  local_project(default_nix = FALSE)
  expect_error(use_repro_dockerfile(run = "Rscript analysis.R"), "default.nix")
})

test_that("errors unless run is a single string", {
  local_project()
  expect_error(use_repro_dockerfile(run = c("a", "b")))
  expect_error(use_repro_dockerfile(run = 1))
})

test_that("writes a Dockerfile with the run command substituted", {
  local_project()
  path <- expect_invisible(use_repro_dockerfile(run = "quarto render paper.qmd"))

  expect_identical(path, "Dockerfile")
  expect_true(file.exists("Dockerfile"))

  txt <- readLines("Dockerfile")
  expect_true(any(grepl("nix-build", txt, fixed = TRUE)))
  expect_true(any(grepl(
    'nix-shell default.nix --run "quarto render paper.qmd"', txt, fixed = TRUE)))
  expect_false(any(grepl("{{", txt, fixed = TRUE)))
})
