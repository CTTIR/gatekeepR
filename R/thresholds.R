# Threshold estimation for identity and conditional identity markers.

.gk_finite_values <- function(x, min_n) {
  x <- x[is.finite(x)]
  if (length(x) < min_n) return(NULL)
  if (length(unique(x)) < 2L) return(NULL)
  x
}

.gk_density <- function(x, args) {
  lower <- args$lower_quantile %||% 0.001
  upper <- args$upper_quantile %||% 0.999
  lo <- stats::quantile(x, lower, names = FALSE, type = 7)
  hi <- stats::quantile(x, upper, names = FALSE, type = 7)
  if (!is.finite(lo) || !is.finite(hi) || hi <= lo) return(NULL)
  stats::density(x, from = lo, to = hi, n = as.integer(args$grid_n))
}

.gk_density_modes <- function(density, min_relative_height) {
  y <- density$y
  peaks <- which(diff(sign(diff(y))) == -2L) + 1L
  peaks <- peaks[y[peaks] >= max(y) * min_relative_height]
  peaks[order(y[peaks], decreasing = TRUE)]
}

.gk_no_separation <- function(status = "NOT_CALLABLE_NO_SEPARATION",
                               details = "The method did not find a separated positive population.") {
  list(
    status = status, estimate = NA_real_, crossing = NA_real_,
    negative_q99 = NA_real_, auc = NA_real_, n_positive_pool = 0L,
    n_negative_pool = 0L, positive_populations = NA_character_,
    negative_populations = NA_character_, rule = NA_character_,
    details = details, evidence = NULL
  )
}

.gk_auc_rank <- function(positive, negative) {
  positive <- positive[is.finite(positive)]
  negative <- negative[is.finite(negative)]
  np <- length(positive)
  nn <- length(negative)
  if (np < 1L || nn < 1L) return(NA_real_)
  ranks <- rank(c(negative, positive), ties.method = "average")
  (sum(ranks[seq.int(nn + 1L, nn + np)]) - np * (np + 1) / 2) / (np * nn)
}

.gk_estimate_valley <- function(x, args) {
  v <- .gk_finite_values(x, as.integer(args$min_n))
  if (is.null(v)) return(.gk_no_separation("NOT_CALLABLE_UNDERPOWERED",
    "Too few distinct finite values for density estimation."
  ))
  d <- .gk_density(v, args)
  if (is.null(d)) return(.gk_no_separation())
  modes <- .gk_density_modes(d, args$min_relative_height)
  if (length(modes) < 2L) return(.gk_no_separation())
  modes <- sort(modes[seq_len(2L)])
  between <- seq.int(modes[[1L]], modes[[2L]])
  valley <- between[which.min(d$y[between])]
  lower_height <- min(d$y[modes])
  depth <- if (lower_height > 0) 1 - d$y[valley] / lower_height else 0
  if (!is.finite(depth) || depth < args$min_depth) {
    return(.gk_no_separation(details = "The density valley is too shallow to call."))
  }
  negative <- v[v <= d$x[valley]]
  positive <- v[v > d$x[valley]]
  if (length(negative) < 2L || length(positive) < 2L) {
    return(.gk_no_separation("NOT_CALLABLE_UNDERPOWERED",
      "The two density pools are underpowered."
    ))
  }
  list(
    status = "CALLABLE", estimate = d$x[valley], crossing = d$x[valley],
    negative_q99 = unname(stats::quantile(negative, 0.99)),
    auc = .gk_auc_rank(positive, negative),
    n_positive_pool = length(positive), n_negative_pool = length(negative),
    positive_populations = NA_character_, negative_populations = NA_character_,
    rule = "valley", details = "Two supported density modes with a separating valley.",
    evidence = list(grid = d$x, density = d$y, modes = d$x[modes],
      positive_values = positive, negative_values = negative)
  )
}

.gk_estimate_tail <- function(x, args) {
  v <- .gk_finite_values(x, as.integer(args$min_n))
  if (is.null(v)) return(.gk_no_separation("NOT_CALLABLE_UNDERPOWERED",
    "Too few distinct finite values for density estimation."
  ))
  d <- .gk_density(v, args)
  if (is.null(d)) return(.gk_no_separation())
  peak <- which.max(d$y)
  hit <- which(seq_along(d$x) > peak & d$y <= args$peak_fraction * d$y[peak])
  cut <- if (length(hit)) d$x[hit[[1L]]] else {
    unname(stats::quantile(v, args$fallback_quantile))
  }
  right <- mean(v > cut)
  mirror <- 2 * d$x[peak] - cut
  left <- mean(v < mirror)
  if (!is.finite(cut) || right <= 0 || right < args$min_tail_excess * max(left, 1 / length(v))) {
    return(.gk_no_separation(details = "The high tail is not larger than the mirrored background tail."))
  }
  negative <- v[v <= cut]
  positive <- v[v > cut]
  if (length(negative) < 2L || length(positive) < 2L) {
    return(.gk_no_separation("NOT_CALLABLE_UNDERPOWERED",
      "The two tail pools are underpowered."
    ))
  }
  list(
    status = "CALLABLE", estimate = cut, crossing = cut,
    negative_q99 = unname(stats::quantile(negative, 0.99)),
    auc = .gk_auc_rank(positive, negative),
    n_positive_pool = length(positive), n_negative_pool = length(negative),
    positive_populations = NA_character_, negative_populations = NA_character_,
    rule = "tail", details = "The high density tail exceeds the mirrored background tail.",
    evidence = list(grid = d$x, density = d$y, peak = d$x[peak],
      positive_values = positive, negative_values = negative)
  )
}

.gk_mix_loglik <- function(x, weight, mean, sd) {
  a <- log(weight[[1L]]) + stats::dnorm(x, mean[[1L]], sd[[1L]], log = TRUE)
  b <- log(weight[[2L]]) + stats::dnorm(x, mean[[2L]], sd[[2L]], log = TRUE)
  maxab <- pmax(a, b)
  sum(maxab + log(exp(a - maxab) + exp(b - maxab)))
}

.gk_estimate_mixture <- function(x, args) {
  v <- .gk_finite_values(x, as.integer(args$min_n))
  if (is.null(v)) return(.gk_no_separation("NOT_CALLABLE_UNDERPOWERED",
    "Too few distinct finite values for mixture estimation."
  ))
  q <- stats::quantile(v, c(0.25, 0.75), names = FALSE)
  mu <- c(q[[1L]], q[[2L]])
  sd0 <- stats::sd(v)
  sig <- c(stats::sd(v[v <= mu[[1L]]]), stats::sd(v[v >= mu[[2L]]]))
  sig[!is.finite(sig) | sig <= 0] <- max(sd0 / 2, 1e-6)
  weight <- c(0.5, 0.5)
  ll_old <- -Inf
  for (iter in seq_len(as.integer(args$max_iter))) {
    log_a <- log(weight[[1L]]) + stats::dnorm(v, mu[[1L]], sig[[1L]], log = TRUE)
    log_b <- log(weight[[2L]]) + stats::dnorm(v, mu[[2L]], sig[[2L]], log = TRUE)
    maxab <- pmax(log_a, log_b)
    ra <- exp(log_a - maxab) / (exp(log_a - maxab) + exp(log_b - maxab))
    rb <- 1 - ra
    weight <- c(mean(ra), mean(rb))
    mu <- c(sum(ra * v) / sum(ra), sum(rb * v) / sum(rb))
    sig <- c(
      sqrt(sum(ra * (v - mu[[1L]])^2) / sum(ra)),
      sqrt(sum(rb * (v - mu[[2L]])^2) / sum(rb))
    )
    sig[!is.finite(sig) | sig <= 1e-8] <- max(sd0 / 100, 1e-6)
    if (mu[[1L]] > mu[[2L]]) {
      mu <- rev(mu); sig <- rev(sig); weight <- rev(weight); ra <- 1 - ra
    }
    ll <- .gk_mix_loglik(v, weight, mu, sig)
    if (abs(ll - ll_old) <= args$tol * (1 + abs(ll))) break
    ll_old <- ll
  }
  ll_two <- .gk_mix_loglik(v, weight, mu, sig)
  ll_one <- sum(stats::dnorm(v, mean(v), stats::sd(v), log = TRUE))
  bic_two <- -2 * ll_two + 5 * log(length(v))
  bic_one <- -2 * ll_one + 2 * log(length(v))
  overlap <- stats::pnorm((mu[[1L]] - mu[[2L]]) / sig[[2L]]) +
    1 - stats::pnorm((mu[[2L]] - mu[[1L]]) / sig[[1L]])
  if (!is.finite(overlap) || bic_two >= bic_one || overlap > args$max_overlap) {
    return(.gk_no_separation(details = "The two-component mixture does not separate the signal."))
  }
  a <- 1 / (2 * sig[[1L]]^2) - 1 / (2 * sig[[2L]]^2)
  b <- -mu[[1L]] / sig[[1L]]^2 + mu[[2L]] / sig[[2L]]^2
  c <- mu[[1L]]^2 / (2 * sig[[1L]]^2) - mu[[2L]]^2 / (2 * sig[[2L]]^2) +
    log(weight[[2L]] / sig[[2L]]) - log(weight[[1L]] / sig[[1L]])
  roots <- if (abs(a) < 1e-12) -c / b else {
    disc <- b^2 - 4 * a * c
    if (disc < 0) numeric() else c((-b - sqrt(disc)) / (2 * a), (-b + sqrt(disc)) / (2 * a))
  }
  roots <- roots[is.finite(roots) & roots > mu[[1L]] & roots < mu[[2L]]]
  cut <- if (length(roots)) roots[[1L]] else mean(mu)
  negative <- v[v <= cut]
  positive <- v[v > cut]
  list(
    status = "CALLABLE", estimate = cut, crossing = cut,
    negative_q99 = unname(stats::quantile(negative, 0.99)),
    auc = .gk_auc_rank(positive, negative),
    n_positive_pool = length(positive), n_negative_pool = length(negative),
    positive_populations = NA_character_, negative_populations = NA_character_,
    rule = "mixture", details = "A separated two-component Gaussian mixture.",
    evidence = list(values = v, posterior_positive = 1 - ra,
      means = mu, sds = sig, weights = weight, bic_one = bic_one, bic_two = bic_two,
      overlap = overlap, positive_values = positive, negative_values = negative)
  )
}

.gk_estimate_population_crossing <- function(x, populations, args, min_auc,
                                             seed) {
  keep <- is.finite(x) & !is.na(populations)
  x <- x[keep]
  populations <- populations[keep]
  if (length(x) < 2L || length(unique(populations)) < 2L) {
    return(.gk_no_separation("NOT_CALLABLE_NO_POPULATION",
      "The embedding has fewer than two usable populations."
    ))
  }
  avg <- mean(x)
  spread <- stats::sd(x)
  if (!is.finite(spread) || spread <= 0) return(.gk_no_separation())
  means <- tapply(x, populations, mean)
  positive_ids <- names(means)[means > avg + args$positive_z * spread]
  negative_ids <- names(means)[means < avg + args$negative_z * spread]
  take <- function(ids) {
    unlist(lapply(ids, function(id) {
      values <- x[populations == id]
      if (length(values) > args$max_per_population) {
        values[.gk_with_seed(seed, sample.int(length(values), args$max_per_population))]
      } else values
    }), use.names = FALSE)
  }
  positive <- take(positive_ids)
  negative <- take(negative_ids)
  if (length(positive) < 20L || length(negative) < 20L) {
    return(.gk_no_separation("NOT_CALLABLE_UNDERPOWERED",
      "The selected embedding populations are underpowered."
    ))
  }
  auc <- .gk_auc_rank(positive, negative)
  auc <- max(auc, 1 - auc)
  crossing <- .gk_crossing(positive, negative, args$n_grid)
  if (!is.finite(crossing) || !is.finite(auc) || auc < min_auc) {
    return(.gk_no_separation(details = "The selected populations do not have a valid crossing."))
  }
  cut <- crossing
  if (identical(args$rule, "max_crossing_q99")) {
    cut <- max(cut, unname(stats::quantile(negative, args$negative_quantile)))
  }
  list(
    status = "CALLABLE", estimate = cut, crossing = crossing,
    negative_q99 = unname(stats::quantile(negative, args$negative_quantile)),
    auc = auc, n_positive_pool = length(positive), n_negative_pool = length(negative),
    positive_populations = paste(positive_ids, collapse = ","),
    negative_populations = paste(negative_ids, collapse = ","),
    rule = args$rule, details = "Separated embedding populations with a density crossing.",
    evidence = list(positive_values = positive, negative_values = negative,
      population_means = means, auc = auc)
  )
}

.gk_crossing <- function(positive, negative, n_grid = 2048L) {
  rng <- range(c(positive, negative), finite = TRUE)
  if (!all(is.finite(rng)) || diff(rng) <= 0) return(NA_real_)
  pd <- stats::density(positive, from = rng[[1L]], to = rng[[2L]], n = n_grid)
  nd <- stats::density(negative, from = rng[[1L]], to = rng[[2L]], n = n_grid)
  peak <- which.max(nd$y)
  hit <- which(seq_along(pd$x) > peak & pd$y >= nd$y)
  if (length(hit)) pd$x[hit[[1L]]] else NA_real_
}

.gk_threshold_correction <- function(prepared, correction) {
  if (is.null(correction)) return(prepared$score)
  if (inherits(correction, "gk_corrected")) return(correction$matrix)
  if (inherits(correction, "gk_correction_model")) {
    return(gk_correct(prepared, correction)$matrix)
  }
  .gk_abort("{.arg correction} must be the result of {.fn gk_correct}.", class = "input")
}

.gk_override_for <- function(config, image_id, marker) {
  hits <- vapply(config$overrides, function(o) {
    identical(o$image_id, image_id) && identical(o$marker, marker) && is.na(o$parent)
  }, logical(1))
  if (any(hits)) config$overrides[[which(hits)[[1L]]]] else NULL
}

#' Estimate per-image marker thresholds
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Estimates thresholds for identity and conditional identity markers. Support
#' is checked before estimation, and every method records a status rather than
#' inventing a cut when its input is absent, underpowered or not separated.
#' State-marker thresholds are estimated by [gk_state_calls()] after parent
#' labels are available.
#'
#' @param prepared A [gk_prepare()] result.
#' @param config The configuration used to prepare the data.
#' @param embedding An optional [gk_embed()] result for
#'   `population_crossing`.
#' @param correction `NULL` or a [gk_correct()] result.
#' @param seed Seed used when sampling embedding populations.
#'
#' @return An object of class `gk_thresholds`, a data frame with one row per
#'   image and marker, the threshold result columns, and an `evidence`
#'   attribute containing density and pool data for plotting.
#'
#' @examples
#' prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
#' thresholds <- gk_thresholds(prep, gk_example_config(), seed = 1L)
#' thresholds[, c("marker", "status", "estimate")]
#'
#' @family thresholds
#' @export
gk_thresholds <- function(prepared, config, embedding = NULL, correction = NULL,
                          seed = 5420L) {
  .gk_check_class(prepared, "gk_prepared")
  .gk_check_class(config, "gk_config")
  if (!identical(prepared$config_sha256, gk_config_hash(config))) {
    .gk_abort("{.arg config} does not match the configuration used for preparation.", class = "state")
  }
  if (!is.null(embedding)) .gk_check_class(embedding, "gk_embedding")
  seed <- .gk_check_count(seed)
  score <- .gk_threshold_correction(prepared, correction)
  pm <- config$panel$markers
  pm <- pm[pm$role %in% .gk_gating_roles, , drop = FALSE]
  images <- unique(prepared$cells$image_id)
  rows <- list()
  evidence <- list()
  evidence_id <- 0L
  add_evidence <- function(value) {
    if (is.null(value)) return(NA_character_)
    evidence_id <<- evidence_id + 1L
    id <- paste0("E", sprintf("%04d", evidence_id))
    evidence[[id]] <<- value
    id
  }
  for (img in images) {
    idx <- which(prepared$cells$image_id == img)
    for (j in seq_len(nrow(pm))) {
      mk <- pm$marker[[j]]
      override <- .gk_override_for(config, img, mk)
      method <- override$threshold_method %||% pm$threshold_method[[j]]
      args <- if (!is.null(override) && !is.null(override$threshold_args)) {
        override$threshold_args
      } else {
        config$panel$threshold_args[[mk]]
      }
      args <- .gk_method_args(method, args %||% list(), role = pm$role[[j]])
      cb <- prepared$callability[prepared$callability$image_id == img &
        prepared$callability$marker == mk, , drop = FALSE]
      base_status <- if (nrow(cb)) cb$status[[1L]] else "NOT_CALLABLE_UNAVAILABLE"
      result <- if (grepl("^NOT_CALLABLE", base_status)) {
        .gk_no_separation(base_status, cb$details[[1L]] %||% "Marker is not callable.")
      } else if (identical(method, "manual")) {
        value <- args$value
        if (is.numeric(value) && length(value) == 1L && is.finite(value)) {
          list(
            status = "MANUAL", estimate = as.double(value), crossing = NA_real_,
            negative_q99 = NA_real_, auc = NA_real_, n_positive_pool = 0L,
            n_negative_pool = 0L, positive_populations = NA_character_,
            negative_populations = NA_character_, rule = "manual",
            details = "Fixed threshold from configuration.", evidence = NULL
          )
        } else .gk_no_separation("NOT_CALLABLE_NO_SEPARATION", "Manual threshold is not finite.")
      } else if (identical(method, "population_crossing")) {
        if (is.null(embedding)) {
          .gk_no_separation("NOT_CALLABLE_NO_POPULATION", "This method requires an embedding.")
        } else {
          pop <- embedding$population[idx]
          .gk_estimate_population_crossing(
            score[idx, mk], pop, args, config$panel$min_support[[mk]]$min_auc, seed
          )
        }
      } else {
        switch(method,
          valley = .gk_estimate_valley(score[idx, mk], args),
          tail = .gk_estimate_tail(score[idx, mk], args),
          mixture = .gk_estimate_mixture(score[idx, mk], args),
          .gk_no_separation(details = paste("Unknown threshold method", method))
        )
      }
      rows[[length(rows) + 1L]] <- data.frame(
        image_id = img, marker = mk, parent = NA_character_, role = pm$role[[j]],
        method = method, status = result$status, estimate = result$estimate,
        crossing = result$crossing, negative_q99 = result$negative_q99,
        auc = result$auc, n_positive_pool = as.integer(result$n_positive_pool),
        n_negative_pool = as.integer(result$n_negative_pool),
        positive_populations = result$positive_populations,
        negative_populations = result$negative_populations, rule = result$rule,
        args_json = .gk_canonical_json(args), details = result$details,
        evidence_ref = add_evidence(result$evidence), stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  attr(out, "evidence") <- evidence
  attr(out, "config_sha256") <- prepared$config_sha256
  attr(out, "source_sha256") <- prepared$source_sha256
  class(out) <- c("gk_thresholds", "data.frame")
  out
}

#' @export
print.gk_thresholds <- function(x, ...) {
  tab <- table(x$status)
  cli::cli_text(
    "{.cls gk_thresholds}: {nrow(x)} image x marker result{?s}"
  )
  cli::cli_bullets(c(
    "*" = "Statuses: {.val {paste(names(tab), as.integer(tab), sep = ' = ', collapse = '; ')}}",
    "*" = "Evidence records: {length(attr(x, 'evidence'))}"
  ))
  invisible(x)
}
