buildtime_fastmap <- fastmap::fastmap()
runtime <- new.env(parent = emptyenv())
lazy_fastmap <- structure(new.env(parent = emptyenv()), class = "lazy_fastmap")

#' @export
save_fastmap_value <- function(
  map_type = Sys.getenv("REPREX_FASTMAP_INIT_STYLE"),
  value_type = Sys.getenv("REPREX_FASTMAP_VALUE_TYPE")
) {
  value <- switch(value_type,
    "parquet" = {
      f <- tempfile("mtcars", fileext = ".parquet")
      arrow::write_parquet(mtcars, f)
      arrow::read_parquet(f)
    },
    "integer" = 1L
  )

  set <- switch(map_type,
    "buildtime" = buildtime_fastmap$set,
    "runtime" = runtime$fastmap$set,
    "lazy-fastmap" = lazy_fastmap$set,
    "lazy-stub" = lazy_fastmap$set,
    "global" = .GlobalEnv$fastmap$set
  )

  set("value", value)
  value
}
