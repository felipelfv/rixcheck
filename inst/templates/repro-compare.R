# Compare freshly produced outputs against the versions committed at HEAD.
# Written by rixcheck::use_repro_check(); self-contained on purpose (base R
# plus git only), so the CI environment needs no extra packages.
#
# Usage: Rscript tools/repro-compare.R <path>... [--tolerance <tol>]
#
# For each git-tracked file under the given paths, the committed version
# (git show HEAD:<file>) is compared against the file now in the working
# tree, i.e. the one the pipeline just regenerated:
#   - with no tolerance: byte-for-byte (md5), for every file
#   - with --tolerance:  .rds files are compared via all.equal() on the
#     deserialized objects; all other files remain byte-for-byte
# Exits nonzero if any file differs, failing the CI job.

args <- commandArgs(trailingOnly = TRUE)
tol_at <- which(args == "--tolerance")
tolerance <- NULL
if (length(tol_at) == 1) {
  tolerance <- as.numeric(args[tol_at + 1])
  args <- args[-c(tol_at, tol_at + 1)]
}
if (length(args) == 0) stop("No output paths given.")

files <- system2("git", c("ls-files", "--", args), stdout = TRUE)
if (length(files) == 0) stop("No git-tracked files found under: ",
                             paste(args, collapse = " "))

baseline_of <- function(f) {
  tmp <- tempfile(fileext = paste0("_", basename(f)))
  status <- system2("git", c("show", shQuote(paste0("HEAD:", f))),
                    stdout = tmp, stderr = FALSE)
  if (status != 0) return(NULL)
  tmp
}

results <- data.frame(file = files, status = NA_character_,
                      stringsAsFactors = FALSE)

for (i in seq_along(files)) {
  f <- files[i]
  if (!file.exists(f)) { results$status[i] <- "MISSING (not regenerated)"; next }
  base <- baseline_of(f)
  if (is.null(base)) { results$status[i] <- "NO BASELINE (not in HEAD)"; next }

  bitwise <- unname(tools::md5sum(f)) == unname(tools::md5sum(base))
  if (bitwise) { results$status[i] <- "MATCH (bitwise)"; next }

  if (!is.null(tolerance) && grepl("\\.rds$", f, ignore.case = TRUE)) {
    ok <- tryCatch(
      isTRUE(all.equal(readRDS(base), readRDS(f), tolerance = tolerance)),
      error = function(e) FALSE)
    results$status[i] <- if (ok)
      sprintf("MATCH (within tolerance %g)", tolerance) else "DIVERGE"
  } else {
    results$status[i] <- "DIVERGE"
  }
}

cat("\n== reproducibility comparison against HEAD ==\n")
cat(sprintf("  %-50s %s\n", results$file, results$status), sep = "")

bad <- !grepl("^MATCH", results$status)
cat(sprintf("\n%d of %d outputs reproduced.\n", sum(!bad), nrow(results)))
if (any(bad)) quit(status = 1)
