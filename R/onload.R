.onLoad <- function(...) {
  # if statement toggled here:


  runtime$fastmap <- fastmap::fastmap()
  .GlobalEnv$fastmap <- fastmap::fastmap()

  lazy_style <- Sys.getenv("REPREX_FASTMAP_INIT_STYLE")

  # use inlined boolean logic instead of if-else blocks to avoid inserting
  # a if block into this file, the only if block should be toggled at the
  # top for testing.

  # use S3, lazily create a fastmap
  (identical(lazy_style, "lazy-fastmap") && {
    registerS3method("$", "lazy_fastmap", function(x, name) {
      is.null(get0("state", envir = x)) && {
        assign("state", fastmap::fastmap(), envir = x)
        TRUE
      }
      get0("state", envir = x)[[name]]
    })
    TRUE
  }) ||

  # use S3, but don't lazily create a fastmap
  (identical(lazy_style, "lazy-stub") && {
    registerS3method("$", "lazy_fastmap", function(x, name) {
      list(set = function(...) {})[[name]]
    })
    TRUE
  })
}
