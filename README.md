Macrophyte dynamics in the Nemunas River Basin: an open-source remote sensing workflow for basin-scale monitoring.

This repository contains all code, data, and outputs associated with the paper:

Levachou, S. & Stonevičius, E. (in review). Macrophyte dynamics in the Nemunas River Basin: an open-source remote sensing workflow for basin-scale monitoring.


Overview
This repository provides a fully reproducible workflow for mapping and analysing aquatic macrophyte coverage in the Nemunas River basin (2017–2024) using Sentinel-2 imagery and phenology-based NIR reflectance thresholds. The workflow covers macrophyte identification, structural typology development, and temporal regime classification.

Repository Structure
macrophytes/
│
├── GEE                                 
|   └── macrophyte_classification.js    # Google Earth Engine workflow
│
├── R/
│   ├── Typology_structural.R           # Coverage-based spatial typology (Rse)
│   └── Typology_dynamic.R              # Temporal regime classification
│
├── data/
│   ├── cover_abs.csv                   # Macrophyte cover data in m2 for 173 waterbodies (2017–2024)
|   ├── cover_pct.csv                   # Macrophyte cover data in percents for 173 waterbodies (2017–2024)
|   ├── cover_pct_change.csv            # Change of macrophyte cover data in percents for 55 waterbodies (2017–2024)
│   ├── waterbodies_xy.csv              # Waterbody points coordinates
|   ├── HyBasNeman.shp                  # Bassin polygon
|   └── Nemunas.shp                     # Polygons of waterbodies (173)
│
└── figures/
    ├── Macrophyte typology Rse.png    
    ├── typology dynamic map.png
    └── Typology_dyn_fig.png

Requirements
Google Earth Engine

A registered GEE account (free at earthengine.google.com)
Sentinel-2 Surface Reflectance image collection
Here is the link to GEE repo - https://code.earthengine.google.com/fce33cdd64916ddfe823670103724690

R (version 4.0 or higher)
rinstall.packages(c("readr", "sf", "ggplot2", "dplyr", 
                   "tidyr", "rnaturalearth", "ggrepel", "corrplot"))


Workflow Summary

Macrophyte identification — Sentinel-2 NIR (B8) band thresholds applied in GEE to classify emergent, submerged and floating macrophytes, and open water. Alternative temporal windows (April, August, September) were calibrated to address persistent cloud cover in the study region.

Structural typology — A structural ratio index (Rse = submerged and floating mean cover / emergent mean cover) was calculated for each water body. Lakes were classified into three structural types: emergent-dominated, no dominance, and submerged and floating-dominated.
Temporal regime typology — Annual rates of change in emergent and submerged and floating cover were used to classify 56 lakes into dynamic types (Weak, Coordinated growth, Shift towards submerged and floating, Shift towards emergent) and dynamic character (Directional, Fluctuating).


Data
The dataset covers 173 lakes and reservoirs in the Nemunas River basin across eight years (2017–2024). Water body polygons were derived from national hydrographic datasets. All data are provided in CSV and shapefile format.

Citation
If you use this code or data, please cite:

Levachou, S. & Stonevičius, E. (in review). Macrophyte dynamics in the Nemunas River Basin: an open-source remote sensing workflow for basin-scale monitoring.


License
This repository is licensed under the MIT License. You are free to use, modify, and distribute the code with attribution.

Contact
For questions or collaboration enquiries, please open a GitHub issue or contact the corresponding author.
