# Install and load required packages
library(ggplot2)
library(sf)
library(dplyr)

# Step 1: Load the shapefile for Kenyan counties
kenya_counties <- st_read("gadm41_KEN_1.shp")

# Step 2: Create a data frame with the contraceptive use data from the map
contraceptive_data <- data.frame(
  County = c("Kakamega", "Uasin Gishu", "Elgeyo-Marakwet", "Vihiga", "Nandi", "Kisumu", "Kericho",
             "Kisii", "Nyamira", "Bomet", "Nakuru", "Nyandarua", "Nyeri", "Murang'a", "Kirinyaga",
             "Embu", "Tharaka-Nithi", "Kiambu", "Nairobi", "Machakos", "Makueni", "Turkana",
             "Marsabit", "Wajir", "Samburu", "Isiolo", "Meru", "Garissa", "Tana River", "Lamu",
             "Trans Nzoia", "West Pokot", "Bungoma", "Busia", "Siaya", "Homa Bay", "Migori",
             "Narok", "Kajiado", "Taita Taveta", "Kilifi", "Kwale", "Mombasa", "Mandera", "Laikipia",
             "Baringo", "Kitui"),
  Percentage = c(63, 63, 59, 60, 60, 57, 60, 64, 62, 58, 67, 67, 71, 67, 71, 71, 68, 68, 68, 69,
                 64, 31, 6, 3, 25, 29, 70, 11, 23, 3, 65, 31, 64, 55, 43, 54, 59, 52, 57, 48, 45,
                 35, 42, 2, 60, 48, 62)
)

# Step 3: Merge the contraceptive data with the shapefile
kenya_counties <- kenya_counties %>%
  left_join(contraceptive_data, by = c("NAME_1" = "County"))

# Step 4: Creating the Plot
kenya_counties <- kenya_counties %>%
  mutate(Percentage_bin = cut(Percentage,
                              breaks = c(2, 15, 35, 56, 66, 75),
                              labels = c("2-15%", "16-35%", "36-55%", "56-65%", "66-75%"),
                              include.lowest = TRUE)) %>%
  # Create a label column combining county name and percentage
  mutate(label = paste0(NAME_1, "\n", Percentage, "%")) %>%
  # Calculate area to determine which counties are "small"
  mutate(area = as.numeric(st_area(geometry)),
         # Define small counties as those below a certain area threshold
         is_small = area < quantile(area, 0.3),  # Bottom 30% in area
         # Assign numbers to small counties
         number = if_else(is_small, row_number(), NA_integer_))

# Create a legend table for small counties
small_counties <- kenya_counties %>%
  filter(is_small) %>%
  st_drop_geometry() %>%
  select(number, NAME_1, Percentage) %>%
  arrange(number) %>%
  mutate(legend_entry = paste0(number, " ", NAME_1, " ", Percentage, "%"))

# Combine the legend entries into a single string
legend_text <- paste(small_counties$legend_entry, collapse = "\n")

# Get the bounding box of the map to position the small counties legend
bbox <- st_bbox(kenya_counties)
x_range <- bbox["xmax"] - bbox["xmin"]
y_range <- bbox["ymax"] - bbox["ymin"]

# Plot the choropleth map with the percentage legend at the bottom-left
p <- ggplot(data = kenya_counties) +
  geom_sf(aes(fill = Percentage_bin), color = "white") +
  scale_fill_manual(
    values = c("2-15%" = "#FFFFCC", 
               "16-35%" = "#FFEDA0", 
               "36-55%" = "#FC4E2A", 
               "56-65%" = "#FC4E2A", 
               "66-75%" = "#BD0026"),
    name = " ",
    guide = guide_legend(title.position = "top", title.hjust = 0.5)
  ) +
  # Add labels for larger counties
  geom_sf_text(data = kenya_counties %>% filter(!is_small),
               aes(label = label), size = 2.5, color = "black", check_overlap = TRUE) +
  # Add numbers for smaller counties
  geom_sf_text(data = kenya_counties %>% filter(is_small),
               aes(label = number), size = 2.5, color = "black", fontface = "bold") +
  # Add the small counties legend on the right, below the title/subtitle
  annotate("text",
           x = bbox["xmax"] + 0.001 * x_range,
           y = bbox["ymax"] - 0.3 * y_range,
           label = legend_text,
           hjust = 0,
           vjust = 1,
           size = 3,
           color = "black",
           fontface = "plain") +
  theme_minimal() +
  labs(
    title = "Map of Modern Contraceptive Use by County",
    subtitle = "Percentage of currently married women age 15-49 using a modern contraceptive method",
    caption = "Source: KDHS-2022 | Developed by Omondi Robert"
  ) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5),
    # Move the percentage legend to the bottom-left
    legend.position = "bottom",
    legend.justification = "left",
    legend.box = "horizontal",
    # Adjust plot margins to ensure space for the small counties legend on the right
    plot.margin = margin(t = 1, r = 6, b = 2, l = 1, unit = "cm"),
    # Remove grid lines (graticules)
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    # Remove axis labels (coordinates)
    axis.text = element_blank(),
    axis.title = element_blank(),
    axis.ticks = element_blank(),
    plot.caption = element_text(face = "bold", size = 8, hjust = 0.5)  # hjust = 0 to left-align
  ) +
  # Expand the plot area to accommodate the small counties legend on the right
  coord_sf(xlim = c(bbox["xmin"], bbox["xmax"] + 0.2 * x_range),
           ylim = c(bbox["ymin"], bbox["ymax"]),
           expand = FALSE)

# Print the plot
print(p)

# Step 5: Save the plot if needed
ggsave("contraceptive_use_map.png", width = 12, height = 8)
