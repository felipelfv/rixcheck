#' Add a Dockerfile that runs the project through its Nix environment
#'
#' Writes a Dockerfile that installs Nix inside a container, builds the
#' project's pinned environment from its committed `default.nix`, and runs
#' the given command through `nix-shell`. The container is a convenience
#' wrapper for users without Nix; the environment itself is still defined
#' entirely by `default.nix`, so the Docker layer adds portability without
#' adding a second, competing environment description.
#'
#' @param run Single shell command executed inside `nix-shell` when the
#'   container starts, e.g. `"quarto render Manuscript/article.qmd"`.
#'
#' @return Invisibly, the path to the written Dockerfile.
#' @export
use_repro_dockerfile <- function(run) {
  stopifnot(is.character(run), length(run) == 1)
  if (!file.exists("default.nix")) {
    stop("No default.nix found in the current directory.\n",
         "Generate one first, e.g. with rix::rix(date = ..., r_pkgs = ...).",
         call. = FALSE)
  }
  template <- readLines(
    system.file("templates", "Dockerfile", package = "rixcheck"),
    warn = FALSE)
  txt <- paste(template, collapse = "\n")
  txt <- sub("{{RUN}}", run, txt, fixed = TRUE)
  writeLines(txt, "Dockerfile")
  message("Wrote Dockerfile")
  invisible("Dockerfile")
}
