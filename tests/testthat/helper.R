# Run a test inside a fresh temporary project directory, optionally
# containing a placeholder default.nix.
local_project <- function(default_nix = TRUE, .local_envir = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = .local_envir)
  withr::local_dir(dir, .local_envir = .local_envir)
  if (default_nix) writeLines("{ }", "default.nix")
  invisible(dir)
}
