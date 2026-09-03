#' Generate a default.nix from a committed session info file
#'
#' Many researchers share only a `sessionInfo.txt` instead of a lockfile
#' through renv, for example. This function is tailored to such former files
#' (i.e., output of `sessioninfo::session_info()` or of base
#' `sessionInfo()`). It then calls on `rix::rix()` with the R version,
#' snapshot date, and attached packages inferred from it. Note that rix
#' still defines the environment, while rixcheck only derives the arguments
#' from the project's own reproducibility evidence.
#'
#' The two formats differ in what they can pin:
#' * `sessioninfo::session_info()` output records the date it was captured.
#'   That date (snapped to the nearest earlier `rix::available_dates()`
#'   entry) becomes `rix(date = ...)`.
#' * Base `sessionInfo()` output has no capture date, so only the R version
#'   is pinned, via `rix(r_ver = ...)`.
#'
#' Either way the fidelity is date-level, not version-level: a library
#' accumulated over months never matches a single snapshot date exactly.
#' The generated environment is a coherent one from around the time of the
#' session, not a copy of the original library.
#'
#' @param session_info_path Path to the session info file.
#' @param project_path Directory where `rix::rix()` writes `default.nix`.
#' @param return_rix_call If `TRUE`, return the unevaluated `rix::rix()`
#'   call instead of executing it, to inspect or adjust before running.
#' @param ... Further arguments passed on to `rix::rix()`, e.g.
#'   `ide = "rstudio"` or `system_pkgs = "quarto"`.
#'
#' @return Invisibly, the path to the written `default.nix` (or, with
#'   `return_rix_call = TRUE`, the unevaluated call).
#' @export
sessioninfo2nix <- function(session_info_path = "sessionInfo.txt",
                            project_path = ".",
                            return_rix_call = FALSE,
                            ...) {
  if (!requireNamespace("rix", quietly = TRUE)) {
    stop("sessioninfo2nix() needs the 'rix' package: install.packages(\"rix\")",
         call. = FALSE)
  }
  if (!file.exists(session_info_path)) {
    stop("No session info file found at '", session_info_path, "'.",
         call. = FALSE)
  }

  info <- parse_session_info(readLines(session_info_path, warn = FALSE))

  if (length(info$attached) == 0) {
    warning("No attached packages found in '", session_info_path,
            "', so generating an environment with R only.", call. = FALSE)
  }

  rix_args <- list(r_pkgs = info$attached, project_path = project_path)
  if (!is.null(info$date)) {
    rix_args$date <- snap_to_available_date(info$date)
    message("Pinning to rstats-on-nix snapshot ", rix_args$date,
            " (capture date ", info$date, ").")
  } else {
    rix_args$r_ver <- info$r_ver
    message("No capture date in '", session_info_path,
            "' (base sessionInfo() format), so pinning R version ",
            info$r_ver, " only.")
  }
  rix_args <- utils::modifyList(rix_args, list(...))

  rix_call <- as.call(c(quote(rix::rix), rix_args))
  if (return_rix_call) {
    return(rix_call)
  }

  eval(rix_call)
  message("Note: packages come from one snapshot date, not the exact ",
          "versions in the session info file.")
  invisible(file.path(project_path, "default.nix"))
}

# Parse the text of a session info file into
# list(r_ver, date (or NULL), attached).
parse_session_info <- function(lines) {
  r_ver_line <- grep("R version [0-9]+[.][0-9]+[.][0-9]+", lines, value = TRUE)
  if (length(r_ver_line) == 0) {
    stop("Could not find an R version in the session info file.",
         call. = FALSE)
  }
  r_ver <- sub(".*R version ([0-9]+[.][0-9]+[.][0-9]+).*", "\\1",
               r_ver_line[[1]])

  # sessioninfo::session_info() output has a "setting  value" table whose
  # "version" row holds the R version. Base sessionInfo() starts the file
  # with "R version ..." directly.
  if (any(grepl("^\\s*version\\s+R version", lines))) {
    parse_sessioninfo_pkg(lines, r_ver)
  } else {
    parse_base_sessioninfo(lines, r_ver)
  }
}

parse_sessioninfo_pkg <- function(lines, r_ver) {
  date <- NULL
  date_line <- grep("^\\s*date\\s+[0-9]{4}-[0-9]{2}-[0-9]{2}", lines,
                    value = TRUE)
  if (length(date_line) > 0) {
    date <- sub("^\\s*date\\s+([0-9]{4}-[0-9]{2}-[0-9]{2}).*", "\\1",
                date_line[[1]])
  }

  pkg_header <- grep("Packages", lines)
  attached <- character(0)
  if (length(pkg_header) > 0 && pkg_header[[1]] < length(lines)) {
    body <- lines[(pkg_header[[1]] + 1):length(lines)]
    # attached packages carry a "*" between name and version. A digit after
    # the "*" skips the table header ("package * version ..."), and rows may
    # start with V/P/D/R problem flags (version/path/DLL/removed mismatches).
    # CRAN names have >= 2 characters, so a lone flag letter can't be a name
    pat <- "^\\s*(?:[VPDR]{1,4}\\s+)?([A-Za-z][A-Za-z0-9.]+)\\s+\\*\\s+[0-9]"
    starred <- grep(pat, body, value = TRUE, perl = TRUE)
    attached <- sub(paste0(pat, ".*"), "\\1", starred, perl = TRUE)
  }

  list(r_ver = r_ver, date = date, attached = sort(unique(attached)))
}

parse_base_sessioninfo <- function(lines, r_ver) {
  start <- grep("^other attached packages:", lines)
  attached <- character(0)
  if (length(start) > 0) {
    body <- lines[-seq_len(start[[1]])]
    ends <- which(!nzchar(trimws(body)) | grepl(":\\s*$", body))
    section_end <- if (length(ends) > 0) ends[[1]] else length(body) + 1
    tokens <- unlist(strsplit(body[seq_len(section_end - 1)], "\\s+"))
    tokens <- tokens[grepl("_", tokens, fixed = TRUE)]
    attached <- sub("_[^_]*$", "", tokens)
  }
  list(r_ver = r_ver, date = NULL, attached = sort(unique(attached)))
}

# Latest rstats-on-nix snapshot on or before the capture date: every version
# in the session's library is at most that old, so the snapshot can only be
# equal-or-newer than the library, never older.
snap_to_available_date <- function(date) {
  avail <- as.Date(rix::available_dates())
  ok <- avail[avail <= as.Date(date)]
  if (length(ok) == 0) {
    stop("Capture date ", date, " predates the earliest rstats-on-nix ",
         "snapshot (", min(avail), ").", call. = FALSE)
  }
  as.character(max(ok))
}
