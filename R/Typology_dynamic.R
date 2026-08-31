# =============================================================================
# Temporal Regime Typology of Macrophytes
#
# Description: Classifies 55 lakes by their temporal dynamics in emergent (EM)
#              and submerged/floating (SFM) macrophyte coverage over 2017-2024.
#              Each lake receives a dynamic type (direction of change) and
#              dynamic character (consistency of change), combined into a
#              final temporal regime label.
#
# Inputs:  cover_pct_change.csv  — annual changes in EM and SFM coverage (%)
#          morf_xy (sf object)   — waterbody centroids, produced by
#                                  structural_typology.R (run that script first)
#
# Outputs: Summary tables of dynamic type and character
#          Scatter plot of dynamic regimes
#          Map of dynamic types across the basin

library(readr)
library(sf)
library(ggplot2)
library(rnaturalearth)
library(dplyr)
library(tidyr)
library(ggrepel)

# Note: this script uses countries_clip, countries_lab, basin, bb, and morf_xy
# produced by structural_typology.R — run that script first.

# ── 1. LOAD DATA ──────────────────────────────────────────────────────────────

Macro_change <- read_csv("cover_pct_change.csv")

# ── 2. CALCULATE MEAN ANNUAL RATES OF CHANGE ──────────────────────────────────

# Mean annual change in emergent and submerged/floating cover (% per year)
Macro_change$dEM_mean <- rowMeans(Macro_change[, paste0("dEM", 18:24)], na.rm = TRUE)
Macro_change$dSM_mean <- rowMeans(Macro_change[, paste0("dSM", 18:24)], na.rm = TRUE)

# Mean annual change in total macrophyte cover (EM + SFM combined, % per year)
Macro_change$dmac_mean <- rowMeans(
  cbind(
    Macro_change$dEM18 + Macro_change$dSM18,
    Macro_change$dEM19 + Macro_change$dSM19,
    Macro_change$dEM20 + Macro_change$dSM20,
    Macro_change$dEM21 + Macro_change$dSM21,
    Macro_change$dEM22 + Macro_change$dSM22,
    Macro_change$dEM23 + Macro_change$dSM23,
    Macro_change$dEM24 + Macro_change$dSM24
  ), na.rm = TRUE)

# ── 3. CALCULATE INTERANNUAL VARIABILITY ──────────────────────────────────────

# Standard deviation of annual changes — used to distinguish directional
# from fluctuating dynamics
Macro_change$sd_dEM <- apply(Macro_change[, paste0("dEM", 18:24)], 1, sd, na.rm = TRUE)
Macro_change$sd_dSM <- apply(Macro_change[, paste0("dSM", 18:24)], 1, sd, na.rm = TRUE)

# ── 4. CLASSIFICATION THRESHOLDS ──────────────────────────────────────────────

# Threshold for total cover change: separates weak from substantial change
# Sensitivity analysis confirmed stability across ±25% variation
eps_mac    <- 0.15   # % per year — total macrophyte cover change

# Threshold for structural shift: detects directional shifts between vegetation types
eps_struct <- 0.11   # % per year — difference between SFM and EM change rates

# Thresholds for dynamic character: median standard deviation across all lakes
sd_EM_thr <- median(Macro_change$sd_dEM, na.rm = TRUE)
sd_SM_thr <- median(Macro_change$sd_dSM, na.rm = TRUE)

# ── 5. CLASSIFY DYNAMIC TYPE ──────────────────────────────────────────────────

# Four dynamic types based on total cover trajectory and structural shift direction
Macro_change$dyn_type <- with(Macro_change, ifelse(
  abs(dmac_mean) <= eps_mac,
  "Weak",
  ifelse(
    dmac_mean > eps_mac & abs(dSM_mean - dEM_mean) <= eps_struct,
    "Coordinated growth",
    ifelse(
      dmac_mean > eps_mac & (dSM_mean - dEM_mean) > eps_struct,
      "Shift towards submerged-floating",
      ifelse(
        dmac_mean > eps_mac & (dEM_mean - dSM_mean) > eps_struct,
        "Shift towards emergent",
        "Other"
      )
    )
  )
))

# ── 6. CLASSIFY DYNAMIC CHARACTER ─────────────────────────────────────────────

# Directional: both EM and SFM standard deviations below their respective medians
# Fluctuating: at least one standard deviation exceeds its median threshold
Macro_change$dyn_character <- with(Macro_change, ifelse(
  sd_dEM < sd_EM_thr & sd_dSM < sd_SM_thr,
  "Directional",
  "Fluctuating"
))

# Combined temporal regime label
Macro_change$dyn_full_type <- paste(
  Macro_change$dyn_type,
  Macro_change$dyn_character,
  sep = " - "
)

# ── 7. SUMMARY TABLES ─────────────────────────────────────────────────────────

table(Macro_change$dyn_type)
table(Macro_change$dyn_character)
table(Macro_change$dyn_full_type)

# ── 8. SCATTER PLOT OF DYNAMIC REGIMES ────────────────────────────────────────

# Two-dimensional classification space:
# x-axis: mean annual change in total cover
# y-axis: difference between SFM and EM change rates
# Dashed lines show classification thresholds

ggplot(Macro_change,
       aes(x = dmac_mean,
           y = dSM_mean - dEM_mean,
           color = dyn_type,
           shape = dyn_character)) +
  geom_hline(yintercept =  eps_struct, linetype = "dashed", color = "grey60") +
  geom_hline(yintercept = -eps_struct, linetype = "dashed", color = "grey60") +
  geom_vline(xintercept =  eps_mac,    linetype = "dashed", color = "grey60") +
  geom_point(size = 3, alpha = 0.8) +
  theme_minimal() +
  labs(
    x     = "Mean annual change in total macrophyte cover (%/year)",
    y     = "Difference between SFM and EM change rates (%/year)",
    color = "Dynamic type",
    shape = "Dynamic character"
  )

# ── 9. MAP OF DYNAMIC TYPES ───────────────────────────────────────────────────

# Join dynamic type results to waterbody coordinates
xy <- morf_xy %>% select(fid_1, X, Y)

Macro_change_xy <- Macro_change %>%
  left_join(xy, by = "fid_1") %>%
  st_as_sf(coords = c("X", "Y"), crs = 4326, remove = FALSE)

ggplot() +
  geom_sf(data = countries_clip, fill = "gray99", color = "gray20") +
  geom_sf_text(data = countries_lab, aes(label = admin), size = 3, color = "gray20") +
  geom_sf(data = basin, fill = NA, color = "darkblue", linewidth = 0.3) +
  geom_sf(
    data = Macro_change_xy,
    aes(fill = dyn_type),
    shape = 21,
    size  = 1.6,
    alpha = 0.8,
    stroke = 0.6
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
  labs(fill = "Dynamic type", x = NULL, y = NULL)
