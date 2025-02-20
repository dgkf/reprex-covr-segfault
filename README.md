
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

  - **fastmap value**: the type of value to be stored in the `fastmap`
  - **fastmap init**: how the `fastmap` is initialized  
    either at [build, runtime,
    lazily](https://github.com/dgkf/reprex-covr-segfault/blob/02913e0e5d397a33574b056bc78cb168933aae69/R/parquet-fastmap.R#L1-L3),
    or in the [gloabl
    env](https://github.com/dgkf/reprex-covr-segfault/blob/02913e0e5d397a33574b056bc78cb168933aae69/R/onload.R#L5-L6)
  - **`.onLoad` if()**: whether there is an `if` block in the `.onLoad`
    function  
    believe it or not, this affects whether `covr` segfaults in some
    cases.
  - **covr source and version**: either released `covr` on **CRAN** or
    the dev build of covr.

Note that S3 methods are registered `onLoad` because registering them
using the `NAMESPACE` had a similar effect to using an `.onLoad` `if ()`
block.

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
  "fastmap value" = c("integer", "data.frame", "parquet"),
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 40.00%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
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
    ## ## reprex.covr.segfault Coverage: 41.03%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 80.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 21 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 22 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 23 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 24 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 25 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 26 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 27 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 28 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 29 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 30 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 31 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 32 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 33 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 34 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 35 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 36 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 37 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 38 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 39 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 42.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 40 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         data.frame
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 43.59%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 85.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 41 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 42 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 48.72%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 43 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 44 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         global
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 48.72%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 45 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 46 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 48.72%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 47 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 48 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-stub
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 48.72%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 49 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 50 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpqsvHJb/R_LIBS2333139a0442/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpqsvHJb/R_LIBS2333139a0442"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpqsvHJb/R_LIBS2333139a0442"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 51 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpwQM2Ib/R_LIBS233ca746cef84/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpwQM2Ib/R_LIBS233ca746cef84"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpwQM2Ib/R_LIBS233ca746cef84"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 52 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         lazy-fastmap
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/Rtmpg3Soi7/R_LIBS234634932fa5f/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmpg3Soi7/R_LIBS234634932fa5f"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmpg3Soi7/R_LIBS234634932fa5f"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 53 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 54 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpPbgNcO/R_LIBS235c741fa0478/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpPbgNcO/R_LIBS235c741fa0478"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpPbgNcO/R_LIBS235c741fa0478"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 55 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpbswsK9/R_LIBS2366036eacfde/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpbswsK9/R_LIBS2366036eacfde"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpbswsK9/R_LIBS2366036eacfde"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 56 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         runtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpSVNKqn/R_LIBS236f96d69ba6c/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpSVNKqn/R_LIBS236f96d69ba6c"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpSVNKqn/R_LIBS236f96d69ba6c"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 57 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## reprex.covr.segfault Coverage: 47.50%
    ## ## R/onload.R: 0.00%
    ## ## R/parquet-fastmap.R: 95.00%
    ## ## > 
    ## ## >  
    ## 
    ## running scenario 58 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_cran", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpHTf60I/R_LIBS2385d2d724579/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpHTf60I/R_LIBS2385d2d724579"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpHTf60I/R_LIBS2385d2d724579"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 59 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/RtmpClKfzH/R_LIBS238f6525ab430/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpClKfzH/R_LIBS238f6525ab430"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/RtmpClKfzH/R_LIBS238f6525ab430"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted 
    ## 
    ## running scenario 60 ... 
    ## ## > .libPaths(c("/tmp/RtmpbfI6aS/lib_covr_dev", "/usr/local/lib/R/site-library",  "/usr/local/lib/R/library"))
    ## ## > print(Sys.getenv()[which(startsWith(names(Sys.getenv()), 'REPREX'))])
    ## ## REPREX_FASTMAP_INIT_STYLE
    ## ##                         buildtime
    ## ## REPREX_FASTMAP_VALUE_TYPE
    ## ##                         parquet
    ## ## > covr::package_coverage()
    ## ## Error: Failure in `/tmp/Rtmp1odfkf/R_LIBS2398f3251eef2/reprex.covr.segfault/reprex.covr.segfault-tests/testthat.Rout.fail`
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
    ## ##  2: covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmp1odfkf/R_LIBS2398f3251eef2"))
    ## ##  3: (function (...) {    covr:::save_trace(Sys.getenv("COVERAGE_DIR", "/tmp/Rtmp1odfkf/R_LIBS2398f3251eef2"))})(<environment>)
    ## ## An irrecoverable exception occurred. R is aborting now ...
    ## ## Segmentation fault (core dumped)
    ## ## Execution halted

``` r
scenarios
```

    ##    fastmap value fastmap init onLoad if() covr remote covr version
    ## 1        integer       global        TRUE        covr        3.6.4
    ## 2        integer       global       FALSE        covr        3.6.4
    ## 3        integer       global        TRUE  r-lib/covr   3.6.4.9004
    ## 4        integer       global       FALSE  r-lib/covr   3.6.4.9004
    ## 5        integer    lazy-stub        TRUE        covr        3.6.4
    ## 6        integer    lazy-stub       FALSE        covr        3.6.4
    ## 7        integer    lazy-stub        TRUE  r-lib/covr   3.6.4.9004
    ## 8        integer    lazy-stub       FALSE  r-lib/covr   3.6.4.9004
    ## 9        integer lazy-fastmap        TRUE        covr        3.6.4
    ## 10       integer lazy-fastmap       FALSE        covr        3.6.4
    ## 11       integer lazy-fastmap        TRUE  r-lib/covr   3.6.4.9004
    ## 12       integer lazy-fastmap       FALSE  r-lib/covr   3.6.4.9004
    ## 13       integer      runtime        TRUE        covr        3.6.4
    ## 14       integer      runtime       FALSE        covr        3.6.4
    ## 15       integer      runtime        TRUE  r-lib/covr   3.6.4.9004
    ## 16       integer      runtime       FALSE  r-lib/covr   3.6.4.9004
    ## 17       integer    buildtime        TRUE        covr        3.6.4
    ## 18       integer    buildtime       FALSE        covr        3.6.4
    ## 19       integer    buildtime        TRUE  r-lib/covr   3.6.4.9004
    ## 20       integer    buildtime       FALSE  r-lib/covr   3.6.4.9004
    ## 21    data.frame       global        TRUE        covr        3.6.4
    ## 22    data.frame       global       FALSE        covr        3.6.4
    ## 23    data.frame       global        TRUE  r-lib/covr   3.6.4.9004
    ## 24    data.frame       global       FALSE  r-lib/covr   3.6.4.9004
    ## 25    data.frame    lazy-stub        TRUE        covr        3.6.4
    ## 26    data.frame    lazy-stub       FALSE        covr        3.6.4
    ## 27    data.frame    lazy-stub        TRUE  r-lib/covr   3.6.4.9004
    ## 28    data.frame    lazy-stub       FALSE  r-lib/covr   3.6.4.9004
    ## 29    data.frame lazy-fastmap        TRUE        covr        3.6.4
    ## 30    data.frame lazy-fastmap       FALSE        covr        3.6.4
    ## 31    data.frame lazy-fastmap        TRUE  r-lib/covr   3.6.4.9004
    ## 32    data.frame lazy-fastmap       FALSE  r-lib/covr   3.6.4.9004
    ## 33    data.frame      runtime        TRUE        covr        3.6.4
    ## 34    data.frame      runtime       FALSE        covr        3.6.4
    ## 35    data.frame      runtime        TRUE  r-lib/covr   3.6.4.9004
    ## 36    data.frame      runtime       FALSE  r-lib/covr   3.6.4.9004
    ## 37    data.frame    buildtime        TRUE        covr        3.6.4
    ## 38    data.frame    buildtime       FALSE        covr        3.6.4
    ## 39    data.frame    buildtime        TRUE  r-lib/covr   3.6.4.9004
    ## 40    data.frame    buildtime       FALSE  r-lib/covr   3.6.4.9004
    ## 41       parquet       global        TRUE        covr        3.6.4
    ## 42       parquet       global       FALSE        covr        3.6.4
    ## 43       parquet       global        TRUE  r-lib/covr   3.6.4.9004
    ## 44       parquet       global       FALSE  r-lib/covr   3.6.4.9004
    ## 45       parquet    lazy-stub        TRUE        covr        3.6.4
    ## 46       parquet    lazy-stub       FALSE        covr        3.6.4
    ## 47       parquet    lazy-stub        TRUE  r-lib/covr   3.6.4.9004
    ## 48       parquet    lazy-stub       FALSE  r-lib/covr   3.6.4.9004
    ## 49       parquet lazy-fastmap        TRUE        covr        3.6.4
    ## 50       parquet lazy-fastmap       FALSE        covr        3.6.4
    ## 51       parquet lazy-fastmap        TRUE  r-lib/covr   3.6.4.9004
    ## 52       parquet lazy-fastmap       FALSE  r-lib/covr   3.6.4.9004
    ## 53       parquet      runtime        TRUE        covr        3.6.4
    ## 54       parquet      runtime       FALSE        covr        3.6.4
    ## 55       parquet      runtime        TRUE  r-lib/covr   3.6.4.9004
    ## 56       parquet      runtime       FALSE  r-lib/covr   3.6.4.9004
    ## 57       parquet    buildtime        TRUE        covr        3.6.4
    ## 58       parquet    buildtime       FALSE        covr        3.6.4
    ## 59       parquet    buildtime        TRUE  r-lib/covr   3.6.4.9004
    ## 60       parquet    buildtime       FALSE  r-lib/covr   3.6.4.9004
    ##    exit status
    ## 1            0
    ## 2            0
    ## 3            0
    ## 4            0
    ## 5            0
    ## 6            0
    ## 7            0
    ## 8            0
    ## 9            0
    ## 10           0
    ## 11           0
    ## 12           0
    ## 13           0
    ## 14           0
    ## 15           0
    ## 16           0
    ## 17           0
    ## 18           0
    ## 19           0
    ## 20           0
    ## 21           0
    ## 22           0
    ## 23           0
    ## 24           0
    ## 25           0
    ## 26           0
    ## 27           0
    ## 28           0
    ## 29           0
    ## 30           0
    ## 31           0
    ## 32           0
    ## 33           0
    ## 34           0
    ## 35           0
    ## 36           0
    ## 37           0
    ## 38           0
    ## 39           0
    ## 40           0
    ## 41           0
    ## 42           0
    ## 43           0
    ## 44           0
    ## 45           0
    ## 46           0
    ## 47           0
    ## 48           0
    ## 49           0
    ## 50           1
    ## 51           1
    ## 52           1
    ## 53           0
    ## 54           1
    ## 55           1
    ## 56           1
    ## 57           0
    ## 58           1
    ## 59           1
    ## 60           1

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
| data.frame    | global       | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | global       | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | global       | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | global       | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | lazy-stub    | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | lazy-stub    | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | lazy-stub    | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | lazy-stub    | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | lazy-fastmap | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | lazy-fastmap | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | lazy-fastmap | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | lazy-fastmap | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | runtime      | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | runtime      | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | runtime      | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | runtime      | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | buildtime    | TRUE        | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | buildtime    | FALSE       | covr        | `v3.6.4`      | :white\_check\_mark: |
| data.frame    | buildtime    | TRUE        | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
| data.frame    | buildtime    | FALSE       | r-lib/covr  | `v3.6.4.9004` | :white\_check\_mark: |
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
