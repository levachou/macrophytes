# =============================================================================
# Structural Typology of Aquatic Macrophytes — Nemunas River Basin
#
# Description: Calculates a structural ratio index (Rse) for each waterbody
#              based on multi-year mean emergent and submerged/floating
#              macrophyte coverage (2017-2024). Classifies waterbodies into
#              three structural types, maps their spatial distribution, and
#              explores associations with lake morphometric characteristics.
#
# Inputs:  cover_pct.csv       — per-waterbody annual macrophyte coverage (%)
#          waterbodies_xy.csv  — waterbody centroids with morphometric variables
#                                (must contain: fid_1, X, Y, RD05, S_m2)
#          HyBasNeman.shp      — Nemunas River basin boundary
#
# Outputs: Density plots of coverage distributions
#          Map of structural types across the basin
#          Pearson correlation matrix (Rse, RD05, S_m2)
#          Spearman correlation test on size-corrected residuals
#
# =============================================================================

library(readr)
library(sf)
library(ggplot2)
library(rnaturalearth)
library(dplyr)
library(tidyr)
library(corrplot)

# ── 1. LOAD DATA ──────────────────────────────────────────────────────────────

Macro   <- read_csv("cover_pct.csv")
morf_xy <- read_csv("waterbodies_xy.csv")
basin   <- st_read("HyBasNeman.shp")

# ── 2. CALCULATE MULTI-YEAR MEANS ─────────────────────────────────────────────

# Mean annual coverage across 2017-2024 for each vegetation class
Macro$EM_mean  <- rowMeans(Macro[, paste0("EM_pct_",  17:24)], na.rm = TRUE)
Macro$SFM_mean <- rowMeans(Macro[, paste0("SFM_pct_", 17:24)], na.rm = TRUE)
Macro$mac_mean <- rowMeans(Macro[, paste0("mac",      17:24)], na.rm = TRUE)

# ── 3. STRUCTURAL RATIO INDEX ─────────────────────────────────────────────────

# Rse = mean submerged/floating cover / mean emergent cover
# Higher values indicate submerged/floating dominance
# Lower values indicate emergent dominance
Macro$Rse <- Macro$SFM_mean / Macro$EM_mean

# ── 4. EXPLORE DISTRIBUTIONS ──────────────────────────────────────────────────

ggplot(Macro, aes(x = mac_mean)) + geom_density() + ggtitle("Total macrophyte cover — mean")
ggplot(Macro, aes(x = EM_mean))  + geom_density() + ggtitle("Emergent cover — mean")
ggplot(Macro, aes(x = SFM_mean)) + geom_density() + ggtitle("Submerged/floating cover — mean")
ggplot(Macro, aes(x = Rse))      + geom_density() + ggtitle("Structural ratio index (Rse)")

# ── 5. CLASSIFY STRUCTURAL TYPES ──────────────────────────────────────────────

# Boundaries set at the 25 and 75 percentiles of the Rse distribution
# (0.60 and 1.29, rounded to 0.6 and 1.3). See section 9 for derivation and
# sensitivity analysis. 

Macro$type_Rse <- NA
Macro$type_Rse[Macro$Rse < 0.6]                      <- "Emergent-dominated"
Macro$type_Rse[Macro$Rse >= 0.6 & Macro$Rse <= 1.3] <- "No dominance"
Macro$type_Rse[Macro$Rse > 1.3]                      <- "Submerged-dominated"

# Summary of group counts
table(Macro$type_Rse)

# ── 6. PREPARE SPATIAL DATA ───────────────────────────────────────────────────

# Load country boundaries for basemap
countries <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(admin %in% c("Lithuania", "Belarus", "Russia", "Poland", "Latvia"))

# Join typology results to waterbody coordinates and morphometric variables
morf_xy <- morf_xy %>%
  left_join(
    Macro %>% select(fid_1, Lake, EM_mean, SFM_mean, mac_mean, Rse, type_Rse),
    by = "fid_1"
  ) %>%
  st_as_sf(coords = c("X", "Y"), crs = 4326, remove = FALSE)

# Crop countries to basin extent
bb             <- st_bbox(basin)
countries_clip <- st_crop(countries, bb)
countries_lab  <- st_point_on_surface(countries_clip)

# ── 7. MAP STRUCTURAL TYPES ───────────────────────────────────────────────────

ggplot() +
  geom_sf(data = countries_clip, fill = "gray99", color = "gray20") +
  geom_sf_text(data = countries_lab, aes(label = admin), size = 3, color = "gray20") +
  geom_sf(data = basin, fill = NA, color = "darkblue", linewidth = 0.3) +
  geom_sf(data = morf_xy, aes(color = type_Rse), size = 1.4, alpha = 0.7) +
  scale_color_manual(
    values = c(
      "Emergent-dominated"  = "darkgreen",
      "No dominance"        = "darkblue",
      "Submerged-dominated" = "darkorange"
    ),
    na.value = "grey85",
    name = "Structural type"
  ) +
  coord_sf(
    xlim = c(bb["xmin"], bb["xmax"]),
    ylim = c(bb["ymin"], bb["ymax"]),
    expand = FALSE
  ) +
  theme_minimal() +
  theme(
    panel.grid.major = element_line(linewidth = 0.3, color = "gray85"),
    panel.grid.minor = element_blank(),
    axis.text        = element_text(size = 8),
    legend.position  = "bottom"
  ) +
  labs(x = NULL, y = NULL)

# ── 8. MORPHOMETRIC CORRELATION ANALYSIS ──────────────────────────────────────

# Prepare correlation dataset — Rse, relative depth (RD05), and lake area (S_m2)
# RD05 = Zr = (Zmax / (0.5 * sqrt(A / pi))) * 100
# S_m2 = lake surface area in square metres
cor_data <- morf_xy %>%
  st_drop_geometry() %>%
  select(Rse, RD05, S_m2) %>%
  na.omit()

# Pearson correlation matrix
cor_matrix <- cor(cor_data, use = "complete.obs")
print(cor_matrix)

corrplot(cor_matrix,
         method = "color",
         type = "upper",
         tl.col = "black",
         addCoef.col = "black",
         number.cex = 0.8,
         mar = c(0, 0, 2, 0))

# Spearman correlation on size-corrected residuals
# Controls for the confounding effect of lake area on both Rse and RD05
res_Rse  <- resid(lm(Rse  ~ S_m2, data = cor_data))
res_RD05 <- resid(lm(RD05 ~ S_m2, data = cor_data))

cor.test(res_Rse, res_RD05, method = "spearman")

# ── 9. THRESHOLD DERIVATION AND SENSITIVITY ───────────────────────────────────
# The Rse distribution is unimodal and continuous, without natural breaks, so
# class boundaries were set at the 25 and 75 percentiles of the observed
# distribution and rounded.

# Derivation: empirical percentiles of Rse
quantile(Macro$Rse, c(0.25, 0.75), na.rm = TRUE)   # -> 0.60 and 1.29, rounded to 0.6 and 1.3

# Classification function with adjustable boundaries
classify <- function(x, lo, hi) {
  cut(x, breaks = c(-Inf, lo, hi, Inf),
      labels = c("Emergent-dominated", "No dominance", "Submerged-dominated"))
}

base <- classify(Macro$Rse, 0.6, 1.3)
table(base)

# Sensitivity: shift both boundaries by a common factor
sens <- data.frame(shift = c(-25, -10, 10, 25)) %>%
  mutate(
    lo    = 0.6 * (1 + shift / 100),
    hi    = 1.3 * (1 + shift / 100),
    same  = mapply(function(a, b) sum(classify(Macro$Rse, a, b) == base, na.rm = TRUE), lo, hi),
    pct   = round(100 * same / sum(!is.na(base)), 1)
  )
print(sens)

# Does the wide "No dominance" class hide a gradient in total cover?
mid <- Macro[base == "No dominance", ]
wilcox.test(mac_mean ~ Rse > median(Rse), data = mid)


# ── 10. SPATIAL AUTOCORRELATION ───────────────────────────────────────────────
# Neighbouring waterbodies share catchment and climatic conditions, so they are
# not independent samples. This section tests for spatial autocorrelation in the
# structural ratio index and refits the morphometric model with a spatially
# explicit error structure.
library(nlme)

pts <- morf_xy %>%
  filter(!is.na(Rse), !is.na(RD05), !is.na(S_m2)) %>%
  as.data.frame()

# Project lon/lat to kilometres so distances and the range parameter are on a
# physical scale. Small jitter breaks the zero distances caused by duplicated
# centroids (fid 128/148, 147/157, 131/152 — coordinates to be corrected).
set.seed(1)
lat0   <- mean(pts$Y)
pts$xk <- pts$X * 111.32 * cos(lat0 * pi / 180) + rnorm(nrow(pts), 0, 0.1)
pts$yk <- pts$Y * 110.57                        + rnorm(nrow(pts), 0, 0.1)

# Moran's I on k-nearest-neighbour weights, permutation test
moran_knn <- function(v, x, y, k = 5, nsim = 999) {
  D <- as.matrix(dist(cbind(x, y)))
  W <- t(apply(D, 1, function(d) {
    w <- as.numeric(rank(d, ties.method = "first") %in% 2:(k + 1)); w / sum(w)
  }))
  I   <- function(z) { z <- z - mean(z); sum(z * (W %*% z)) / sum(z^2) }
  obs <- I(v)
  sim <- replicate(nsim, I(sample(v)))
  c(I = obs, p = (sum(abs(sim) >= abs(obs)) + 1) / (nsim + 1))
}

# 1. Is the index itself clustered?
moran_knn(pts$Rse, pts$xk, pts$yk)

# 2. Non-spatial model, and autocorrelation in its residuals
m_ols <- gls(Rse ~ RD05 + I(S_m2/1e6), data = pts, method = "ML")
summary(m_ols)
moran_knn(residuals(m_ols), pts$xk, pts$yk)

# 3. Spatially explicit model: exponential correlation with a nugget
m_sp <- gls(Rse ~ RD05 + I(S_m2/1e6), data = pts, method = "ML",
            correlation = corExp(value = c(40, 0.5), form = ~ xk + yk, nugget = TRUE))

anova(m_ols, m_sp)                                       # is the spatial model better?
coef(m_sp$modelStruct$corStruct, unconstrained = FALSE)  # range (km) and nugget
summary(m_sp)
moran_knn(residuals(m_sp, type = "normalized"), pts$xk, pts$yk)   # autocorrelation removed?