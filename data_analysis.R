#Libraries ----
library(dplyr)
library(openxlsx)
library(data.table)
library(ggplot2)
library(ggrepel)
library(NADA)
library(tidyr)

#Functions ----
character_feet_to_numeric <- function(h){
  feet_format <- sapply(strsplit(as.character(h),"'|\""),
         function(x){as.numeric(x[1]) + as.numeric(x[2])/12})
  as.numeric(ifelse(!is.na(feet_format), feet_format, h))
}

BootMean <- function(data) {
  B <- 10000
  mean <- numeric(B)
  n = length(data)
  
  set.seed(3437)
  for (i in 1:B) {
    boot <- sample(1:n, size=n, replace = TRUE)
    mean[i] <- mean(data[boot], na.rm = T)
  }
  return(mean)
}

### THEME GRAY ####

theme_gray_etal<- function(base_size = 12, bgcolor = NA) {
    half_line <- base_size/2
    theme(
        line = element_line(colour = "black", size = rel(1.5), 
                            linetype = 1, lineend = "butt"), 
        rect = element_rect(fill = NA, colour = "black",
                            size = 0.5, linetype = 1),
        text = element_text(face = "plain",
                            colour = "black", size = base_size,
                            lineheight = 0.9,  hjust = 0.5,
                            vjust = 0.5, angle = 0, 
                            margin = margin(), debug = FALSE), 
        
        axis.line = element_blank(), 
        axis.text = element_text(size = rel(1.5), colour = "grey10"),
        axis.text.x = element_text(margin = margin(t = half_line/2), 
                                   vjust = 1), 
        axis.text.y = element_text(margin = margin(r = half_line/2),
                                   hjust = 1),
        axis.ticks = element_line(colour = "black", size=1), 
        axis.ticks.length = unit(half_line*0.75, "pt"), 
        axis.title = element_text(size = rel(1.5), colour = "black"),
        axis.title.x = element_text(margin = margin(t = half_line*5,
                                                    b = half_line)),
        axis.title.y = element_text(angle = 90, 
                                    margin = margin(r = half_line*5,
                                                    l = half_line)),
        
        legend.background = element_rect(colour = NA), 
        legend.key = element_rect(colour = NA),
        legend.key.size = unit(2, "lines"), 
        legend.key.height = NULL,
        legend.key.width = NULL, 
        legend.text = element_text(size = rel(1)),
        legend.text.align = NULL,
        legend.title = element_text(size = rel(1)), 
        legend.title.align = NULL, 
        legend.position = "right", 
        legend.direction = NULL,
        legend.justification = "center", 
        legend.box = NULL, 
        
        panel.background = element_rect(fill=bgcolor,colour = "black", size = 2), 
        panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(), 
        panel.spacing = unit(half_line, "pt"), panel.margin.x = NULL, 
        panel.spacing.y = NULL, panel.ontop = FALSE, 
        
        #Facet Labels
        strip.background = element_blank(),
        strip.text = element_text(face="bold",colour = "black", size = rel(1.5)),
        strip.text.x = element_text(margin = margin(t = half_line,
                                                    b = half_line)), 
        strip.text.y = element_text(angle = 0, 
                                    margin = margin(l = half_line, 
                                                    r = half_line)),
        strip.switch.pad.grid = unit(5, "lines"),
        strip.switch.pad.wrap = unit(5, "lines"), 
        
        
        plot.background = element_rect(colour = rgb(119,136,153, max = 255)), 
        plot.title = element_text(size = rel(1.5), 
                                  margin = margin(b = half_line * 1.2)),
        plot.margin = margin(4*half_line, 4*half_line, 4*half_line, 4*half_line),
        complete = TRUE)
}



#Data Cleanup ----
#MDT <- read.csv("mdt-data.csv")
files <- list.files(pattern = ".xlsx", recursive = T)
files <- files[!files %in% c("Site 97_12-21-2021/Ann_s data for site 97 superseded format.xlsx", "Site 21_09-03-2021/Copy of Data for Site #X MO_DA_YR template.xlsx")]
files <- files[!grepl("/~", files)]

#tally translation
materials <- c(rep("Plastic", 34), rep("Fabric and Cloth", 6), rep("Large Items", 6), rep("Biodegradable", 5), rep("Biohazard", 9), rep("Construction", 6), rep("Glass", 4), rep("Metal", 12), rep("Miscellaneous", 10))

data_tallysheet <- read.xlsx(xlsxFile = files[3], colNames = FALSE, sheet = "TallySheet")

data_item_materials <- tibble(
  item = c(data_tallysheet[2:50,1], data_tallysheet[2:50,4]),
  count = c(data_tallysheet[2:50,3], data_tallysheet[2:50,6])
  ) %>%
  filter(!is.na(item)) %>%
  bind_cols(tibble(material = materials)) %>%
    dplyr::filter(count != "Total"|is.na(count)) %>%
    select(-count) %>%
    add_row(item = "Plastic Other (describe)            1  of 2 in creek", material = "Plastic") %>%
    add_row(item = "Fabric Other (describe)            1 of 1 in creek", material = "Fabric and Cloth") %>%
    add_row(item = "Misc. Other  (describe)            1 of 1 in creek", material = "Miscellaneous")
    

for(file in files){
  data_trashassessment <- read.xlsx(xlsxFile = file,  colNames = FALSE, sheet = "TrashAssessment")
  data_vegetatedcondition <- read.xlsx(xlsxFile = file, colNames = FALSE, sheet = "VegetatedCondition")
  data_tallysheet <- read.xlsx(xlsxFile = file, colNames = FALSE, sheet = "TallySheet")
  data_volume <- read.xlsx(xlsxFile = file, colNames = FALSE, sheet = "Volume")
  
  data_trashassessment_clean <- tibble(
    station_id_trashassessment = data_trashassessment[3,2],
    site_description = data_trashassessment[11,2],
    site_type = data_trashassessment[16,2],
    field_crew = data_trashassessment[9,2],
    date = data_trashassessment[3,7],
    start_time = data_trashassessment[4,2],
    start_am_pm =  data_trashassessment[4,3],
    end_time = data_trashassessment[4,5],
    end_am_pm =  data_trashassessment[4,6],
    start_latitude = data_trashassessment[5,2],
    end_latitude = data_trashassessment[6,2],
    start_longitude = data_trashassessment[5,5],
    end_longitude = data_trashassessment[6,5],
    watershed = data_trashassessment[11,8],
    datum = data_trashassessment[5,8],
    left_bank_access =  data_trashassessment[13,3],
    left_bank_facing =  data_trashassessment[13,4],
    right_bank_access =  data_trashassessment[13,7],
    right_bank_facing =  data_trashassessment[13,8],
    channel_type_1 =  data_trashassessment[15,1],
    channel_type_2 =  data_trashassessment[15,2],
    channel_type_3 =  data_trashassessment[15,3],
    channel_type_4 =  data_trashassessment[15,4],
    channel_type_other =  data_trashassessment[15,8],
    is_stream_flowing =  data_trashassessment[16,8],
    reach_length =  data_trashassessment[19,3],
    reach_length_units =  data_trashassessment[19,4],
    wetted_width_a =  data_trashassessment[20,4],
    wetted_width_b =  data_trashassessment[20,6],
    wetted_width_c =  data_trashassessment[20,8],
    wetted_width_units =  data_trashassessment[20,9],
    bankfull_width_a =  data_trashassessment[21,4],
    bankfull_width_b =  data_trashassessment[21,6],
    bankfull_width_c =  data_trashassessment[21,8],
    bankfull_width_units =  data_trashassessment[21,9],
    assessment_width_a =  data_trashassessment[22,4],
    assessment_width_b =  data_trashassessment[22,6],
    assessment_width_c =  data_trashassessment[22,8],
    assessment_width_units =  data_trashassessment[22,9],
    was_trash_picked_up = data_trashassessment[23,4],
    number_outfalls = data_trashassessment[25,8],
    outfall_diameter_1 = data_trashassessment[27,2],
    outfall_diameter_2 = data_trashassessment[27,4],
    outfall_diameter_3 = data_trashassessment[27,6],
    outfall_diameter_4 = data_trashassessment[27,8],
    outfall_trash_1 = data_trashassessment[28,2],
    outfall_trash_2 = data_trashassessment[28,4],
    outfall_trash_3 = data_trashassessment[28,6],
    outfall_trash_4 = data_trashassessment[28,8],
    outfall_trash_amount_1 = data_trashassessment[29,2],
    outfall_trash_amount_2 = data_trashassessment[29,4],
    outfall_trash_amount_3 = data_trashassessment[29,6],
    outfall_trash_amount_4 = data_trashassessment[29,8],
    homeless_encampment_in_200_m = data_trashassessment[30,6],
    comments = data_trashassessment[32,1]
  ) %>%
    mutate(filename = file)
  
  data_vegetatedcondition_clean <- tibble(
    station_id_vegetatedcondition = data_vegetatedcondition[1,2],
    date_vegetated = data_vegetatedcondition[1,4],
    banks_percent_ground_cover = data_vegetatedcondition[7,1],
    banks_percent_understory = data_vegetatedcondition[7,2],
    banks_percent_trees_roots = data_vegetatedcondition[7,3],
    banks_percent_bare_ground = data_vegetatedcondition[7,4],
    banks_percent_total = data_vegetatedcondition[7,5],
    channel_percent_woody_debris = data_vegetatedcondition[11,1],
    channel_percent_aquatic_vegetation = data_vegetatedcondition[11,2],
    channel_percent_algae = data_vegetatedcondition[11,3],
    channel_percent_no_vegetation_or_woody_debris = data_vegetatedcondition[11,4],
    channel_percent_total = data_vegetatedcondition[11,5],
    comments_vegetation = data_vegetatedcondition[12,2] #Not positive this gets it.
  ) %>%
    mutate(filename = file)
  
  #Some station ids not consistent e.g. 13 between the sheets. 
  data_volume_clean <- data_volume[8:16,1:9]
  names(data_volume_clean) <- c("material", "num_buckets", "bucket_size_gallons", "num_bags", "bag_size_gallons", "total_small", "units_small", "large_volume", "units_large")
  data_volume_clean$station_id_volume <- data_volume[1,2]
  data_volume_clean <- data_volume_clean %>%
    mutate(filename = file)
  
  data_tallysheet_clean <- tibble(
    item = c(data_tallysheet[2:50,1], data_tallysheet[2:50,4]),
    count = c(data_tallysheet[2:50,3], data_tallysheet[2:50,6])
  ) %>%
    mutate(station_id_tally = data_tallysheet[1,2],
           date_tally = data_tallysheet[1,4]) %>%
    dplyr::filter(count != "Total"|is.na(count)) %>%
    dplyr::filter(!is.na(item)) %>%
    mutate(count = as.numeric(ifelse(is.na(count), 
                                     0, 
                                     ifelse(count == "M", 
                                            runif(1,11,100), 
                                            ifelse(count == "H", 
                                                   runif(1, 100, 200), 
                                                   count))))) %>%
    left_join(data_item_materials) %>%
    mutate(filename = file)
  
  total_df <- left_join(data_tallysheet_clean, data_volume_clean) %>%
    left_join(left_join(data_vegetatedcondition_clean, data_trashassessment_clean))
  
  write.csv(total_df, paste0(gsub("/.{1,}", "", file), "/total_clean.csv"), row.names = F)
  write.csv(data_trashassessment_clean, paste0(gsub("/.{1,}", "", file), "/trashassessment_clean.csv"), row.names = F)
  write.csv(data_volume_clean, paste0(gsub("/.{1,}", "", file), "/volume_clean.csv"), row.names = F)
  write.csv(data_vegetatedcondition_clean, paste0(gsub("/.{1,}", "", file), "/vegetated_clean.csv"), row.names = F)
  write.csv(data_tallysheet_clean, paste0(gsub("/.{1,}", "", file), "/tallysheet_clean.csv"), row.names = F)
  
}

#Data analysis ----
##Litter quantity analysis ----
clean_files <- list.files(pattern = "total_clean.csv", recursive = T)

clean_joined_file <- rbindlist(lapply(clean_files, fread))

na_material <- clean_joined_file %>%
  filter(is.na(material))
#Why are some of the sites 98 feet?
clean_joined_file_2 <- clean_joined_file %>%
  filter(station_id_trashassessment != 97) %>%
  mutate(reach_length_units_m = 30) %>% #ifelse(reach_length_units == "ft", 
                                        #character_feet_to_numeric(reach_length) * 0.3048, 
                                        #as.numeric(reach_length))) %>%
  mutate(bankfull_width_a_m = ifelse(bankfull_width_units == "ft", 
                                       character_feet_to_numeric(bankfull_width_a) * 0.3048, 
                                       as.numeric(bankfull_width_a))) %>%
  mutate(bankfull_width_b_m = ifelse(bankfull_width_units == "ft", 
                                     character_feet_to_numeric(bankfull_width_b) * 0.3048, 
                                     as.numeric(bankfull_width_b))) %>%
  mutate(bankfull_width_c_m = ifelse(bankfull_width_units == "ft", 
                                     character_feet_to_numeric(bankfull_width_c) * 0.3048, 
                                     as.numeric(bankfull_width_c))) %>%
  mutate(bankfull_width_mean_m = rowMeans(select(., bankfull_width_a_m, bankfull_width_b_m, bankfull_width_c_m), na.rm = TRUE)) %>%
  mutate(reach_area_m2 = reach_length_units_m * bankfull_width_mean_m) %>%
  filter(!is.na(material)) #the NAs are just descriptions of the other column so can be ignored. 
  
#Total survey length
sum(clean_joined_file_2 %>%
      distinct(filename, reach_length_units_m) %>%
      pull(reach_length_units_m))

site_counts <- clean_joined_file_2 %>%
  group_by(filename, reach_length_units_m, reach_area_m2) %>%
  summarise(sum = sum(count)) %>%
  ungroup() %>%
  mutate(sum_per_m = sum/reach_length_units_m,
         sum_per_m2 = sum/reach_area_m2)
#Sum per m2 could be explained by taking an average step spreading your arms out wide and that is how many pieces of trash you would find in that area. 
#Why some 30 m and some 29.8?

site_volumes <- clean_joined_file_2 %>%
  distinct(material, filename, total_small, large_volume, reach_length_units_m, reach_area_m2) %>%
  mutate(sum_volume_m3 = rowSums(select(., total_small, large_volume) %>%
                                mutate(total_small = total_small * 0.00378541,
                                       large_volume = large_volume * 0.0283168), na.rm = TRUE)) %>%
  group_by(filename, reach_length_units_m, reach_area_m2) %>%
  summarise(sum_m3 = sum(sum_volume_m3)) %>%
  ungroup() %>%
  mutate(sum_m3_per_m = sum_m3/reach_length_units_m,
         sum_m3_per_m2 = sum_m3/reach_area_m2) %>%
  mutate(sum_l_per_m = sum_m3_per_m * 1000,
         sum_l_per_m2 = sum_m3_per_m2 * 1000)

counts_and_volumes <- inner_join(site_counts, site_volumes) %>%
  mutate(site_name = gsub("Site", "", gsub("_.{1,}", "", filename))) %>%
  mutate(multiple = sum_l_per_m * sum_per_m)

write.csv(counts_and_volumes, "counts_and_volumes.csv")

distance_to_bay <- clean_joined_file_2 %>%
  distinct(filename, start_latitude, start_longitude, end_latitude, end_longitude)

write.csv(distance_to_bay, "distance_to_bay.csv")
#site 72 appears to be off of the mainstem based on the start point. endpoint is on though, perhaps a typo? 

counts_and_volumes <- read.csv("counts_and_volumes.csv")
#total length of mainstem is 17732.882 meters
#city limits is upstream of site 3, 171 meters
#distances in csv are going upstream. 
distances_added <- read.csv("distances_to_bay_added.csv") %>%
  inner_join(counts_and_volumes) %>%
  mutate(distance_to_bay = 17732.882 - dist) %>%
  mutate(censored_sum = sum == 0) %>%
  mutate(censored_volume = sum_m3 == 0) %>%
  mutate(upstream_of_city = distance_to_bay > 6441 + 171)
  
write.csv(distances_added, "distances_added_count_vol.csv")

options(scipen = 999)

distances_added %>%
  ggplot(aes(x = sum_l_per_m, y = sum_per_m, shape = upstream_of_city, color = log10(multiple))) + 
  geom_point(size = 5) + 
  scale_x_log10() + 
  scale_y_log10() + 
  coord_fixed() +
  scale_color_viridis_c(direction = -1) +
  theme_gray_etal() +
  #geom_label_repel() + 
  labs(x = "Trash Volume per Stream Length (liters/m)", y = "Trash Count per Stream Length (#/m)")
#Were some of the sites not assessed for trash volume? Seems like three of the sites had no volume or count, should correct. 
#Could add distance downstream to this plot and show path dependant hysteresis as one goes downstream. 

#Plot distance to pipes
distances_added %>%
    ggplot(aes(x = distuppipe, y = sum_per_m)) +
    geom_point() +
    theme_gray_etal() + 
    geom_smooth(method = "lm", linetype=0) + 
    scale_x_log10() +
    scale_y_log10() +
    labs(x = "distance to upstream pipe (m)", y = "count per m")
    
#Plot distance to pipes
distances_added %>%
    ggplot(aes(x = distuppipe, y = sum_l_per_m)) +
    geom_point() +
    theme_gray_etal() + 
    geom_smooth(method = "lm", linetype=0) + 
    scale_x_log10() +
    scale_y_log10() +
    labs(x = "distance to upstream pipe (m)", y = "liters per m")


distances_added %>%
  select(distance_to_bay, multiple, sum_per_m, sum_l_per_m) %>%
  rename(`count per m` = sum_per_m, `liters per m` = sum_l_per_m, multiply = multiple) %>%
  pivot_longer(cols = -distance_to_bay) %>%
    ggplot() + 
      geom_point(aes(x = distance_to_bay, y = value, color = name), alpha = 0.5, size = 3) + 
      scale_y_log10() + 
      geom_vline(xintercept = 6441 + 171) + 
      theme_gray_etal() + 
      labs(x = "Distance to Bay (m)", y = "Value") + 
      facet_wrap(. ~ name)
#interesting dip immediately above the town where perhaps there isn't a lot of input from storm drains and there isn't dumping. 

ggplot(distances_added, aes(x = distance_to_bay, y = multiple)) + 
    geom_point(size = 3) + 
    geom_line() + 
    scale_y_log10() + 
    geom_vline(xintercept = 6441 + 171) + 
    theme_gray_etal() + 
    labs(x = "Distance to Bay (m)", y = "Multiple")

ggplot(distances_added, aes(x = distance_to_bay, y = sum_per_m*1000)) + 
  geom_point(size = 3) + 
  geom_line() + 
  #geom_smooth(method = "lm") +
  scale_y_log10() + 
  geom_vline(xintercept = 6441 + 171) + 
  theme_gray_etal() + 
  labs(x = "Distance to Bay (m)", y = "Count per km")
#interesting dip immediately above the town where perhaps there isn't a lot of input from storm drains and there isn't dumping. 

ggplot(distances_added, aes(x = distance_to_bay, y = sum_m3_per_m*1000)) + 
  geom_point(size = 3) + 
  geom_line() + 
  #geom_smooth(method = "lm") +
  scale_y_log10() + 
  geom_vline(xintercept = 6441 + 171) + 
  theme_gray_etal() + 
  labs(x = "Distance to Bay (m)", y = bquote("Volume "~m^3~"per km"))

#interesting dip immediately above the town where perhaps there isn't a lot of input from storm drains and there isn't dumping. 

#stations pre rain
stations_filename <- c("Site 0_10-20-2021/Site #0 10_20_21.xlsx", 
                       "Site 14_10-16-2021/Data for Site #14 10_16_21.xlsx", 
                       "Site 16_10-16-2021/Data for Site #16 10_16_21.xlsx", 
                       "Site 19_10-23-2021/Data for Site #19 10_23_21.xlsx", 
                       "Site 20_10-16-2021/Data for Site #20-relocated 10_16_21.xlsx", 
                       "Site 23_10-23-2021/Data for Site #23-relocated 10_23_21.xlsx", 
                       "Site 25_09-18-2021/Data for Site #25 09_18_21.xlsx")

rain <- distances_added %>%
    mutate(pre_rain = filename %in% stations_filename) %>%
    mutate(pre_rain = ifelse(pre_rain, "Before Storms", "After Storms"))

ggplot(rain, aes(x = distance_to_bay, y = pre_rain)) + 
    geom_point(size = 3) + 
    #geom_line() + 
    #scale_y_log10() + 
    geom_vline(xintercept = 6441 + 171) + 
    theme_gray_etal() +
    labs(x = "Distance to Bay (m)", y = "")

boot_rain <- rain %>%
  group_by(pre_rain) %>%
  summarise(mean_sum_m = mean(sum_per_m), 
            max_mean_sum_m = quantile(BootMean(sum_per_m), 0.975),
            min_mean_sum_m = quantile(BootMean(sum_per_m), 0.025), 
            mean_vol_m = mean(sum_l_per_m), 
            max_mean_vol_m = quantile(BootMean(sum_l_per_m), 0.975),
            min_mean_vol_m = quantile(BootMean(sum_l_per_m), 0.025))


ggplot(rain) + 
    geom_boxplot(aes(x = sum_per_m, y = pre_rain), notch = T) + 
    theme_gray_etal()+ 
    labs(x = "count per m", y = "")

ggplot(rain) + 
    geom_boxplot(aes(x = sum_m3_per_m, y = pre_rain), notch = T) + 
    theme_gray_etal() +
    labs(x = "volume per m", y = "")


ggplot(boot_rain, aes(x = mean_sum_m, y = pre_rain)) + 
  geom_point() + 
  geom_errorbar(aes(xmin = min_mean_sum_m, xmax = max_mean_sum_m)) +
  theme_gray_etal()+ 
  labs(x = "mean count per m", y = "")

ggplot(boot_rain, aes(x = mean_vol_m, y = pre_rain)) + 
  geom_point() + 
  geom_errorbar(aes(xmin = min_mean_vol_m, xmax = max_mean_vol_m)) +
  theme_gray_etal()+ 
  labs(x = "mean vol per m", y = "")


#estimate total amount of litter in the stream
library(ggdist)

ggplot(distances_added, aes(x = sum_per_m*1000, y = "Count")) + 
ggdist::stat_halfeye(
    ## custom bandwidth
    adjust = .5, 
    ## adjust height
    width = .6, 
    ## move geom to the right
    justification = -.2, 
    ## remove slab interval
    .width = 0, 
    point_colour = NA
) + 
    geom_boxplot(
        width = .12, 
        ## remove outliers
        outlier.color = NA ## `outlier.shape = NA` works as well
    ) +
    ## add dot plots from {ggdist} package
    geom_point(
        size = 1.3,
        alpha = .3,
        position = position_jitter(
            seed = 1, width = .1
        )
    ) + 
    ## remove white space on the left
    coord_cartesian() +
    scale_x_log10() +
    theme_gray_etal() + 
    labs(x = "Count per km", y = "")

ggplot(distances_added %>% filter(sum_m3_per_m != 0), aes(x = sum_m3_per_m * 1000, y = "Volume")) + 
    ggdist::stat_halfeye(
        ## custom bandwidth
        adjust = .5, 
        ## adjust height
        width = .6, 
        ## move geom to the right
        justification = -.2, 
        ## remove slab interval
        .width = 0, 
        point_colour = NA
    ) + 
    geom_boxplot(
        width = .12, 
        ## remove outliers
        outlier.color = NA ## `outlier.shape = NA` works as well
    ) +
    ## add dot plots from {ggdist} package
    geom_point(
        size = 1.3,
        alpha = .3,
        position = position_jitter(
            seed = 1, width = .1
        )
    ) + 
    ## remove white space on the left
    coord_cartesian() +
    theme_gray_etal() + 
    scale_x_log10() +
    labs(x = bquote("Volume "~m^3~"per km"), y = "Proportion Smaller")

hist(distances_added$sum_per_m)

hist(BootMean(distances_added$sum_per_m))
total_count <- mean(distances_added$sum_per_m) * 17732.882
count_range <- quantile(BootMean(distances_added$sum_per_m), c(0.025, 0.975)) * 17732.882
quantile(BootMean(distances_added$sum), c(0.025, 0.975)) 
mean(distances_added$sum)#2X above average compared to southern California in 2013 BIGHT. But 95% confidence intervals overlap so there is more work to be done. sccwrp estimated mean 31 ± 2.5.

hist(BootMean(distances_added$sum_m3_per_m))
total_volume <- mean(distances_added$sum_m3_per_m) * 17732.882
volume_range <- quantile(BootMean(distances_added$sum_m3_per_m), c(0.025, 0.975)) * 17732.882
#average commercial dump truck is 10 cubic meters. So anywhere from 1-6 dump trucks. 
#people create 5 pounds of trash per day. 
#https://www.epa.gov/sites/default/files/2016-04/documents/volume_to_weight_conversion_factors_memorandum_04192016_508fnl.pdf
cubic_meters_per_person_day <- 4.9/138*0.764555
number_of_people_days <- total_volume/cubic_meters_per_person_day

#pinole population 19,279
percent_of_population_littering_all <- number_of_people_days/19279 * 100

fit_vol = cenros(distances_added$sum_m3_per_m, distances_added$censored_volume)
fit_sum = cenros(distances_added$sum_per_m, distances_added$censored_sum)

hist(log(fit_vol$modeled))
hist(log(fit_sum$modeled))

set.seed(211)

fittedvalues_sum <- sample(fit_sum$modeled[fit_sum$censored], 
                           length(fit_sum$modeled[fit_sum$censored]), 
                           replace = F)
fittedvalues_vol <-  sample(fit_vol$modeled[fit_vol$censored], 
                            length(fit_vol$modeled[fit_vol$censored]), replace = F)
  
distances_added_2 <- distances_added %>%
  mutate(sum_m3_per_m = ifelse(censored_volume, fittedvalues_vol, sum_m3_per_m)) %>%
  mutate(sum_per_m = ifelse(censored_sum, fittedvalues_sum, sum_per_m))
  #impute missing values

total_count_censcorrected <- mean(distances_added_2$sum_per_m) * 17732.882
count_range_censcorrected <- quantile(BootMean(distances_added_2$sum_per_m), c(0.025, 0.975)) * 17732.882
quantile(BootMean(distances_added_2$sum), c(0.025, 0.975)) 
mean(distances_added_2$sum)#2X above average compared to southern California in 2013 BIGHT. But 95% confidence intervals overlap so there is more work to be done. sccwrp estimated mean 31 ± 2.5.

hist(BootMean(distances_added_2$sum_m3_per_m))
total_volume_censcorrected <- mean(distances_added_2$sum_m3_per_m) * 17732.882
volume_range_censcorrected <- quantile(BootMean(distances_added_2$sum_m3_per_m), c(0.025, 0.975)) * 17732.882
number_of_people_days_corrected <- total_volume_censcorrected/cubic_meters_per_person_day
number_of_people_days_corrected_range <- volume_range_censcorrected/cubic_meters_per_person_day

##Litter quality analysis ----
trash_items <- clean_joined_file_2 %>%
  select(item, count, filename) %>%
  group_by(filename) %>%
  mutate(proportion = count/sum(count)) %>%
  ungroup() %>%
  left_join(distances_added_2)

ggplot(trash_items, aes(y=proportion, x=distance_to_bay)) +
  geom_point() + 
  facet_wrap(.~item)

#Cigarette butt proportions
trash_items %>%
    dplyr::filter(item %in% c("Tobacco Wrapper/Pieces", 
                              #"Cigarette - Electronic", 
                              "Cigarette Butts",
                              #"Cigar Tips",
                              "Lighters")) %>%
ggplot(aes(y=proportion*100, x=distance_to_bay)) +
    geom_point() + 
    facet_grid(rows = vars(item)) + 
    geom_vline(xintercept = 6441 + 171) + 
    scale_y_log10(limits = c(0.1,100)) + 
    theme_gray_etal() + 
    labs(x = "Distance to Bay (m)", y = "Percent") 
    
trash_items %>%
    dplyr::filter(item %in% c("Tires")) %>%
    ggplot(aes(y=proportion*100, x=distance_to_bay)) +
    geom_point() + 
    facet_grid(rows = vars(item)) + 
    geom_vline(xintercept = 6441 + 171) + 
    scale_y_log10() + 
    theme_gray_etal() + 
    labs(x = "Distance to Bay (m)", y = "Percent") 

trash_items %>%
    dplyr::filter(item %in% c("Bag Pieces*", 
                              "Wrapper/Wrapper Pieces*", 
                              "Single Use Container", 
                              "Straw/Stirrer", 
                              "Foam Food Containers",
                              "Foam Cups",
                              "Cups",
                              "Chip Bags",
                              "Plastic Bottles",
                              "Foam Plate")) %>%
    mutate(item = gsub("\\*", "", item)) %>%
    ggplot(aes(y=proportion*100, x=distance_to_bay)) +
    geom_point(size = 2, alpha = 0.5) + 
    facet_grid(rows = vars(item)) + 
    geom_vline(xintercept = 6441 + 171) + 
    scale_y_log10(limits = c(0.1,100)) + 
    theme_gray_etal(base_size = 9) + 
    labs(x = "Distance to Bay (m)", y = "Percent") 
#gsub("\\*", "", "Bag Pieces*")
#Might need to remove the sites that had no trash because they will just down weight all the values. 
trash_list <- expand.grid(item = unique(clean_joined_file_2$item),
                          filename = unique(clean_joined_file_2$filename))

trash_items_bootstrap <- trash_items %>%
  select(item, proportion, filename) %>%
  full_join(trash_list) %>%
  filter(!filename %in% c("Site 97_12-21-2021/Data for Site #97 12-21-21.xlsx", 
                          "Site 54_11-13-2021/Data for Site #54 11-13-21.xlsx",
                          "Site 27_11-13-2021/Data for Site #27 11-13-21.xlsx",
                          "Site 33_11-13-2021/Data for Site #33 11-13-21.xlsx", #removing all sites with fewer than 10 pieces. 
                          "Site 41_11-13-2021/Data for Site #41 11-13-21.xlsx")) %>%
  mutate(proportion = ifelse(is.na(proportion), 
                             0, 
                             ifelse(is.nan(proportion), 
                                    0, 
                                    proportion))) %>%
  group_by(item) %>% 
  summarise(mean = mean(proportion), lower = quantile(BootMean(proportion), 0.025), upper =quantile(BootMean(proportion), 0.975))

ggplot(trash_items_bootstrap %>%
         arrange(mean) %>%    # First sort by val. This sort the dataframe but NOT the factor levels
         mutate(item = gsub(" \\(describe\\)", "", gsub("\\*", "", item))) %>%
         mutate(item=factor(item, levels=item)) %>%
         filter(mean > 0.01), aes(x = mean*100, y = item)) +  # This trick update the factor levels) +
  geom_point() + 
  geom_errorbar(aes(xmin = lower*100, xmax = upper*100)) +
  theme_gray_etal(base_size = 8) +
  labs(x = "Mean Percent", y = "")


trash_materials <- clean_joined_file_2 %>%
  select(material, count, filename) %>%
  group_by(filename, material) %>%
  summarise(sum = sum(count)) %>%
  ungroup() %>%
  group_by(filename) %>%
  mutate(proportion = sum/sum(sum)) %>%
  ungroup() %>%
  left_join(distances_added_2 %>%
              select(filename, distance_to_bay)) %>%
  #filter(proportion > 0 & !is.nan(proportion)) %>%
  filter(!is.na(material)) %>% #the NAs are just descriptions of the other column so can be ignored. 
  arrange(distance_to_bay, material)
  

ggplot(trash_materials, aes(x=distance_to_bay, y=proportion, color=material)) + 
  geom_point(size=3) +
  scale_color_viridis_d() + 
  theme_gray_etal() + 
  facet_wrap(.~material) +
  geom_vline(xintercept = 6441 + 171) + 
  scale_y_log10()

trash_list_materials <- expand.grid(material = unique(clean_joined_file_2$material),
                          filename = unique(clean_joined_file_2$filename))

trash_materials_bootstrap <- trash_materials %>%
  select(material, proportion, filename) %>%
  full_join(trash_list_materials) %>%
  filter(!filename %in% c("Site 97_12-21-2021/Data for Site #97 12-21-21.xlsx", 
                          "Site 54_11-13-2021/Data for Site #54 11-13-21.xlsx",
                          "Site 27_11-13-2021/Data for Site #27 11-13-21.xlsx",
                          "Site 33_11-13-2021/Data for Site #33 11-13-21.xlsx", #removing all sites with fewer than 10 pieces. 
                          "Site 41_11-13-2021/Data for Site #41 11-13-21.xlsx")) %>%
  mutate(proportion = ifelse(is.na(proportion), 
                             0, 
                             ifelse(is.nan(proportion), 
                                    0, 
                                    proportion))) %>%
  mutate(proportion = proportion * 100) %>%
  group_by(material) %>% 
  summarise(mean = mean(proportion), lower = quantile(BootMean(proportion), 0.025), upper =quantile(BootMean(proportion), 0.975))

ggplot(trash_materials_bootstrap %>%
         arrange(mean) %>%    # First sort by val. This sort the dataframe but NOT the factor levels
         mutate(material =factor(material, levels=material)) %>%
         filter(mean > 0.01), aes(x = mean, y = material)) +  # This trick update the factor levels) +
  geom_point() + 
  geom_errorbar(aes(xmin = lower, xmax = upper)) +
  theme_gray_etal(base_size = 12) +
  labs(x = "Mean Proportion by Count", y = "")

trash_materials_vol <- clean_joined_file_2 %>%
  distinct(material, filename, total_small, large_volume) %>%
  mutate(sum_volume_m3 = rowSums(select(., total_small, large_volume) %>%
                                   mutate(total_small = total_small * 0.00378541,
                                          large_volume = large_volume * 0.0283168), na.rm = TRUE)) %>%
  #select(material, count, filename) %>%
  group_by(filename, material) %>%
  summarise(sum_vol = sum(sum_volume_m3)) %>%
  #mutate(material = factor(material)) %>%
  ungroup() %>%
  group_by(filename) %>%
  mutate(proportion = sum_vol/sum(sum_vol)) %>%
  ungroup() %>%
  left_join(distances_added_2 %>%
              select(filename, distance_to_bay)) %>%
  #filter(proportion > 0 & !is.nan(proportion)) %>%
  filter(!is.na(material)) %>% #Nas are just descriptions of the other category and can be ignored. 
  arrange(distance_to_bay, material) %>%
  mutate(proportion = proportion * 100)

trash_materials_vol_2 <- clean_joined_file_2 %>%
  distinct(material, filename, total_small, large_volume) %>%
  mutate(sum_volume_m3 = rowSums(select(., total_small, large_volume) %>%
                                   mutate(total_small = total_small * 0.00378541,
                                          large_volume = large_volume * 0.0283168), na.rm = TRUE)) %>%
  #select(material, count, filename) %>%
  group_by(filename, material) %>%
  summarise(sum_vol = sum(sum_volume_m3)) %>%
  #mutate(material = factor(material)) %>%
  ungroup() %>%
  group_by(filename) %>%
  mutate(proportion = sum_vol/sum(sum_vol)) %>%
  ungroup() %>%
  left_join(distances_added_2 %>%
              select(filename, distance_to_bay)) %>%
  #filter(proportion > 0 & !is.nan(proportion)) %>%
  filter(!is.na(material)) %>% #Nas are just descriptions of the other category and can be ignored. 
  arrange(distance_to_bay, material) %>%
  mutate(name = "volume") %>%
  bind_rows(trash_materials %>%
              mutate(name = "count")) %>%
  mutate(proportion = proportion)


ggplot(trash_materials_vol_2, aes(x=distance_to_bay, y=proportion, color=material, shape = name)) + 
  geom_point(size=3, alpha = 0.5) +
  scale_color_viridis_d() + 
  theme_gray_etal() + 
  facet_wrap(.~material) +
  geom_vline(xintercept = 6441 + 171) + 
  scale_y_log10() + 
  labs(x = "Distance to Bay (m)", y = "Percent")

trash_materials_vol_bootstrap <- trash_materials_vol %>%
  select(material, proportion, filename) %>%
  full_join(trash_list_materials) %>%
  filter(!filename %in% c("Site 97_12-21-2021/Data for Site #97 12-21-21.xlsx", 
                          "Site 54_11-13-2021/Data for Site #54 11-13-21.xlsx",
                          "Site 27_11-13-2021/Data for Site #27 11-13-21.xlsx",
                          "Site 33_11-13-2021/Data for Site #33 11-13-21.xlsx", #removing all sites with fewer than 10 pieces. 
                          "Site 41_11-13-2021/Data for Site #41 11-13-21.xlsx")) %>%
  mutate(proportion = ifelse(is.na(proportion), 
                             0, 
                             ifelse(is.nan(proportion), 
                                    0, 
                                    proportion))) %>%
  group_by(material) %>% 
  summarise(mean = mean(proportion), lower = quantile(BootMean(proportion), 0.025), upper =quantile(BootMean(proportion), 0.975)) %>%
  mutate(name = "volume") %>%
  bind_rows(trash_materials_bootstrap %>%
              mutate(name = "count"))

trash_materials_vol_bootstrap %>%
  arrange(name, mean) %>%
  #mutate(material =as.factor(material, levels=material)) %>%
  ggplot(aes(x = mean, y = material)) +  # This trick update the factor levels) +
  geom_point() + 
  geom_errorbar(aes(xmin = lower, xmax = upper)) +
  theme_gray_etal(base_size = 12) +
  labs(x = "Mean Percentage", y = "") + 
  facet_wrap(.~name)

#interesting downstream increase in prevalence of biodegradable and biohazard classes. 
