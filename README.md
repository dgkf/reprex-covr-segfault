
# `covr` segfault reprex

A unique scenario, where a `fastmap` is created and used to store a
`parquet` `data.frame` produces a segfault when `covr` tries to save
traces using `saveRDS`.

In its simplest form, this would be produced from a package that tests a
function such:

``` r
function(f) {
  m <- fastmap::fastmap()  
  m$set("data", arrow::read_parquet(f))
}
```

The details get far messier, so I’ve tested quite a few different
scenarios to try to pin down what is necessary to prompt a segfault:

## Parameters

* **fastmap value**: the type of value to be stored in the `fastmap`
* **fastmap init**: how the `fastmap` is initialized  
  either at
  [build, runtime, lazily](https://github.com/dgkf/reprex-covr-segfault/blob/02913e0e5d397a33574b056bc78cb168933aae69/R/parquet-fastmap.R#L1-L3),
  or in the [gloabl env](https://github.com/dgkf/reprex-covr-segfault/blob/02913e0e5d397a33574b056bc78cb168933aae69/R/onload.R#L5-L6)
* **`.onLoad` if()**: whether there is an `if` block in the `.onLoad` function  
  believe it or not, this affects whether `covr` segfaults in some cases.
* **covr source and version**: either released `covr` on **CRAN** or the dev
  build of covr.

Note that S3 methods are registered `onLoad` because registering them
using the `NAMESPACE` had a similar effect to using an `.onLoad` `if ()` block.

## Tests

<details>

<summary> <strong><i>code</i></strong> </summary>

``` r
# if a dev version of covr is installed in library, will need to be uninstalled

dir.create(lib_covr_cran <- file.path(tempdir(), "lib_covr_cran"))
install.packages("covr", lib = lib_covr_cran)

dir.create(lib_covr_dev <- file.path(tempdir(), "lib_covr_dev"))
remotes::install_github("r-lib/covr", lib = lib_covr_dev, force = TRUE, quiet = TRUE)
# pak::pkg_install("r-lib/covr", lib = lib_covr_dev)

scenarios <- expand.grid(
  "onLoad if()" = c(TRUE, FALSE),
  "covr remote" = c("covr", "r-lib/covr"),
  "covr version" = "",
  "fastmap init" = c("global", "lazy-stub", "lazy-fastmap", "runtime", "buildtime"),
  "fastmap value" = c("integer", "parquet"),
  "exit status" = 0,
  stringsAsFactors = FALSE
)

cols <- c("fastmap value", "fastmap init", "onLoad if()", "covr remote", "covr version", "exit status")
scenarios <- scenarios[, cols]

for (i in seq_len(nrow(scenarios))) {
  cat("running scenario", i, "... \n")
  scenario <- as.list(scenarios[i, ])

  onload <- readLines("R/onload.R")
  onload[[3]] <- if (scenario[["onLoad if()"]]) "  if (TRUE) {}" else ""
  writeLines(onload, "R/onload.R")

  envvars <- c(
    "REPREX_FASTMAP_INIT_STYLE" = scenario[["fastmap init"]],
    "REPREX_FASTMAP_VALUE_TYPE" = scenario[["fastmap value"]]
  )

  libs <- c(
    switch(scenario[["covr remote"]],
      "covr" = lib_covr_cran,
      "r-lib/covr" = lib_covr_dev
    ),
    .libPaths()
  )

  scenarios[[i, "covr version"]] <-
    as.character(packageVersion("covr", lib.loc = libs))

  x <- processx::process$new(
    command = file.path(R.home(), "bin", "R"),
    args = c(
      "--quiet",
      "--vanilla",
      "-e", paste0(collapse = " ", deparse(bquote(.libPaths(.(libs))))),
      "-e", "print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])",
      "-e", "covr::package_coverage()"
    ),
    env = envvars,
    stdout = "|",
    stderr = "2>&1"
  )

  x$wait()
  scenarios[[i, "exit status"]] <- x$get_exit_status()
  cat(paste0("## ", x$read_all_output_lines(), collapse = "\n"), "\n\n")
}
```

    ## running scenario 1 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 2 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 3 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 4 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 5 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 6 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 7 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 8 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 9 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 10 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 11 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 12 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 13 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 14 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 15 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 16 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 17 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 18 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 19 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 37.84%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 20 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         integer
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 38.89%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 82.35%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 21 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 45.95%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 22 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.22%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 23 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 45.95%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 24 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.22%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 25 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 45.95%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 26 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.22%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 27 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 45.95%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 28 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.22%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 29 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 45.95%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 30 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/Rtmp5bRvYa/R_LIBS2050b343837de/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmp5bRvYa/R_LIBS2050b343837de"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmp5bRvYa/R_LIBS2050b343837de"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 31 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/Rtmp5HdWg2/R_LIBS205a4f963a18/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## ndard setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmp5HdWg2/R_LIBS205a4f963a18"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmp5HdWg2/R_LIBS205a4f963a18"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 32 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpppAg36/R_LIBS2063d74965cda/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpppAg36/R_LIBS2063d74965cda"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpppAg36/R_LIBS2063d74965cda"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 33 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 45.95%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 34 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpviiVip/R_LIBS207a1323e487e/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpviiVip/R_LIBS207a1323e487e"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpviiVip/R_LIBS207a1323e487e"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 35 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpeIILIp/R_LIBS2083a79810ce8/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpeIILIp/R_LIBS2083a79810ce8"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpeIILIp/R_LIBS2083a79810ce8"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 36 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpGNSdsU/R_LIBS208d37e34f63a/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpGNSdsU/R_LIBS208d37e34f63a"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpGNSdsU/R_LIBS208d37e34f63a"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 37 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 45.95%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 100.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 38 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpCotbs4/R_LIBS20a375f43118f/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpCotbs4/R_LIBS20a375f43118f"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpCotbs4/R_LIBS20a375f43118f"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 39 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmphGAYWX/R_LIBS20ad03113831f/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmphGAYWX/R_LIBS20ad03113831f"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmphGAYWX/R_LIBS20ad03113831f"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 40 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpOroUrZ/R_LIBS20b69112e703d/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
    ## ## rd setup for testthat.
    ## ## > # It is recommended that you do not modify it.
    ## ## > #
    ## ## > # Where should you do additional test configuration?
    ## ## > # Learn more about the roles of various files in:
    ## ## > # * https://r-pkgs.org/testing-design.html#sec-tests-files-overview
    ## ## > # * https://testthat.r-lib.org/articles/special-files.html
    ## ## > 
    ## ## > library(testthat)
    ## ## > library(reprex.covr.segfault)
    ## ## > 
    ## ## > test_check("reprex.covr.segfault")
    ## ## [ FAIL 0 | WARN 0 | SKIP 0 | PASS 1 ]
    ## ## > 
    ## ## 
    ## ##  *** caught segfault ***
    ## ## address (nil), cause 'memory not mapped'
    ## ## 
    ## ## Traceback:
    ## ##  1: saveRDS(.counters, file = tmp_file)
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpOroUrZ/R_LIBS20b69112e703d"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpOroUrZ/R_LIBS20b69112e703d"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted

``` r
scenarios
```

    ##    fastmap value fastmap init onLoad if() covr remote covr version exit status
    ## 1        integer       global        TRUE        covr        3.6.4           0
    ## 2        integer       global       FALSE        covr        3.6.4           0
    ## 3        integer       global        TRUE  r-lib/covr   3.6.4.9004           0
    ## 4        integer       global       FALSE  r-lib/covr   3.6.4.9004           0
    ## 5        integer    lazy-stub        TRUE        covr        3.6.4           0
    ## 6        integer    lazy-stub       FALSE        covr        3.6.4           0
    ## 7        integer    lazy-stub        TRUE  r-lib/covr   3.6.4.9004           0
    ## 8        integer    lazy-stub       FALSE  r-lib/covr   3.6.4.9004           0
    ## 9        integer lazy-fastmap        TRUE        covr        3.6.4           0
    ## 10       integer lazy-fastmap       FALSE        covr        3.6.4           0
    ## 11       integer lazy-fastmap        TRUE  r-lib/covr   3.6.4.9004           0
    ## 12       integer lazy-fastmap       FALSE  r-lib/covr   3.6.4.9004           0
    ## 13       integer      runtime        TRUE        covr        3.6.4           0
    ## 14       integer      runtime       FALSE        covr        3.6.4           0
    ## 15       integer      runtime        TRUE  r-lib/covr   3.6.4.9004           0
    ## 16       integer      runtime       FALSE  r-lib/covr   3.6.4.9004           0
    ## 17       integer    buildtime        TRUE        covr        3.6.4           0
    ## 18       integer    buildtime       FALSE        covr        3.6.4           0
    ## 19       integer    buildtime        TRUE  r-lib/covr   3.6.4.9004           0
    ## 20       integer    buildtime       FALSE  r-lib/covr   3.6.4.9004           0
    ## 21       parquet       global        TRUE        covr        3.6.4           0
    ## 22       parquet       global       FALSE        covr        3.6.4           0
    ## 23       parquet       global        TRUE  r-lib/covr   3.6.4.9004           0
    ## 24       parquet       global       FALSE  r-lib/covr   3.6.4.9004           0
    ## 25       parquet    lazy-stub        TRUE        covr        3.6.4           0
    ## 26       parquet    lazy-stub       FALSE        covr        3.6.4           0
    ## 27       parquet    lazy-stub        TRUE  r-lib/covr   3.6.4.9004           0
    ## 28       parquet    lazy-stub       FALSE  r-lib/covr   3.6.4.9004           0
    ## 29       parquet lazy-fastmap        TRUE        covr        3.6.4           0
    ## 30       parquet lazy-fastmap       FALSE        covr        3.6.4           1
    ## 31       parquet lazy-fastmap        TRUE  r-lib/covr   3.6.4.9004           1
    ## 32       parquet lazy-fastmap       FALSE  r-lib/covr   3.6.4.9004           1
    ## 33       parquet      runtime        TRUE        covr        3.6.4           0
    ## 34       parquet      runtime       FALSE        covr        3.6.4           1
    ## 35       parquet      runtime        TRUE  r-lib/covr   3.6.4.9004           1
    ## 36       parquet      runtime       FALSE  r-lib/covr   3.6.4.9004           1
    ## 37       parquet    buildtime        TRUE        covr        3.6.4           0
    ## 38       parquet    buildtime       FALSE        covr        3.6.4           1
    ## 39       parquet    buildtime        TRUE  r-lib/covr   3.6.4.9004           1
    ## 40       parquet    buildtime       FALSE  r-lib/covr   3.6.4.9004           1

</details>

| fastmap value | fastmap init | onLoad if() | covr remote | covr version  | exit status          |
| ------------- | ------------ | ----------- | ----------- | ------------- | -------------------- |
| integer       | global       | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | global       | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | global       | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | global       | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | lazy-stub    | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | lazy-stub    | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | lazy-stub    | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | lazy-stub    | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | lazy-fastmap | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | lazy-fastmap | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | lazy-fastmap | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | lazy-fastmap | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | runtime      | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | runtime      | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | runtime      | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | runtime      | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | buildtime    | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | buildtime    | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| integer       | buildtime    | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| integer       | buildtime    | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| parquet       | global       | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| parquet       | global       | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| parquet       | global       | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| parquet       | global       | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| parquet       | lazy-stub    | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| parquet       | lazy-stub    | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| parquet       | lazy-stub    | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| parquet       | lazy-stub    | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| parquet       | lazy-fastmap | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| parquet       | lazy-fastmap | FALSE       | covr        | `v3.6.4`      | :x:                  |
| parquet       | lazy-fastmap | TRUE        | r-lib/covr  | `v3.6.4.9004` | :x:                  |
| parquet       | lazy-fastmap | FALSE       | r-lib/covr  | `v3.6.4.9004` | :x:                  |
| parquet       | runtime      | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| parquet       | runtime      | FALSE       | covr        | `v3.6.4`      | :x:                  |
| parquet       | runtime      | TRUE        | r-lib/covr  | `v3.6.4.9004` | :x:                  |
| parquet       | runtime      | FALSE       | r-lib/covr  | `v3.6.4.9004` | :x:                  |
| parquet       | buildtime    | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| parquet       | buildtime    | FALSE       | covr        | `v3.6.4`      | :x:                  |
| parquet       | buildtime    | TRUE        | r-lib/covr  | `v3.6.4.9004` | :x:                  |
| parquet       | buildtime    | FALSE       | r-lib/covr  | `v3.6.4.9004` | :x:                  |

## Discussion

Documenting a few patterns I’ve noticed while trying to decipher this
bug. I’ll walk through the table above from groups of scenarios from
left to right.

### Fastmap Value

The value type stored is important. `covr` can safely handle integers,
and presumably other atomic data types without issue. I first
encountered the problem with `data.frame`s loaded using `parquet`, so
that is what is used otherwise.

From this, we can tell that solely *using* fastmap to store values is
not sufficient to hit this bug.

## Fastmap Initialization

Next we can look at the way a `fastmap` object is initialized. For
atomic types, even a `fastmap` initialized in the package namespace will
not through an error. It’s not entirely clear when `fastmap` might
allocate memory, but I assume this *is not* something one should
generally do on build anyways.

Scanning further down the table, we can see that using a `fastmap`
defined in the global environment is perfectly fine, so it is not
sufficient to simply use fastmap, it necessarily needs to be used within
the package namespace.

Storing a `parquet` file in a simple list using `lazy-stub` (faking the
`fastmap` api) is also perfectly fine.

## `.onLoad` `if()`

We’ll focus now on the last 12 rows, which showcase a preplexing
behavior using the CRAN version of `covr`.

Broadly, storing a `parquet` `data.frame` in a `fastmap` will cause a
segfault, whether the `fastmap` is initialized at buildtime, at runtime
or lazily as the `fastmap` is accessed by hooking in to the `$` generic.

*However*, bizarrely enough, there are certain snippets of code, that if
present somewhere in the package, will allow `covr` to succeed. One
oddity that I was able to pin down was whether or not `.onLoad`
contained an `if` block. If one exists (and in this case it’s just a `if
(TRUE) {}`), then `covr` is able to dodge a segfault. I think this was
also affected by whether or not an S3 generic was exported in the
`NAMESPACE`, hence why S3 methods are registered only `.onLoad`, but I
didn’t investigate this exhaustively.
