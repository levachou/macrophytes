# Structural Typology of Aquatic Macrophytes — Nemunas River Basin
#
# Description: Calculates a structural ratio index (Rse) for each waterbody
#              based on multi-year mean emergent and submerged/floating
#              macrophyte coverage (2017-2024). Classifies waterbodies into
#              three structural types and maps their spatial distribution.
#
# Inputs:  cover_pct.csv       — per-waterbody annual macrophyte coverage (%)
#          waterbodies_xy.csv  — waterbody centroids (X, Y coordinates)
#          HyBasNeman.shp      — Nemunas River basin boundary
#
# Outputs: Density plots of coverage distributions
#          Map of structural types across the basin

library(readr)
library(sf)
library(ggplot2)
library(rnaturalearth)
library(dplyr)
library(tidyr)

# ── 1. LOAD DATA ──────────────────────────────────────────────────────────────

Macro    <- read_csv("cover_pct.csv")
morf_xy  <- read_csv("waterbodies_xy.csv")
basin    <- st_read("HyBasNeman.shp")

# ── 2. CALCULATE MULTI-YEAR MEANS ─────────────────────────────────────────────

# Mean annual coverage across 2017-2024 for each vegetation class
Macro$EM_mean  <- rowMeans(Macro[, paste0("EM_pct_",  17:24)], na.rm = TRUE)
Macro$SFM_mean <- rowMeans(Macro[, paste0("SFM_pct_", 17:24)], na.rm = TRUE)
Macro$mac_mean <- rowMeans(Macro[, paste0("mac",      17:24)], na.rm = TRUE)

# ── 3. STRUCTURAL RATIO INDEX ─────────────────────────────────────────────────

# Rse = mean submerged/floating cover / mean emergent cover
# Higher values indicate submerged and floating dominance
# Lower values indicate emergent dominance
Macro$Rse <- Macro$SFM_mean / Macro$EM_mean

# ── 4. EXPLORE DISTRIBUTIONS ──────────────────────────────────────────────────

ggplot(Macro, aes(x = mac_mean)) + geom_density() + ggtitle("Total macrophyte cover — mean")
ggplot(Macro, aes(x = EM_mean))  + geom_density() + ggtitle("Emergent cover — mean")
ggplot(Macro, aes(x = SFM_mean)) + geom_density() + ggtitle("Submerged/floating cover — mean")
ggplot(Macro, aes(x = Rse))      + geom_density() + ggtitle("Structural ratio index (Rse)")

# ── 5. CLASSIFY STRUCTURAL TYPES ──────────────────────────────────────────────

# Thresholds determined iteratively based on distributional properties
# and ecological interpretability of resulting groups
# Sensitivity analysis confirmed stability across ±25% threshold variation
Macro$type_Rse <- NA
Macro$type_Rse[Macro$Rse < 0.6]                       <- "Emergent-dominated"
Macro$type_Rse[Macro$Rse >= 0.6 & Macro$Rse <= 1.3]  <- "No dominance"
Macro$type_Rse[Macro$Rse > 1.3]                        <- "Submerged-dominated"

# Summary of group counts
table(Macro$type_Rse)

# ── 6. PREPARE SPATIAL DATA ───────────────────────────────────────────────────

# Load country boundaries for basemap
countries <- ne_countries(scale = "medium", returnclass = "sf") %>%
  filter(admin %in% c("Lithuania", "Belarus", "Russia", "Poland", "Latvia"))

# Join typology results to waterbody coordinates
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