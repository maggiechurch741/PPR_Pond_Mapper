# $fullaug21
# layer value      count
# 1     1 -9999     210776
# 2     1     0 1046034732
# 3     1     1  162695734
# 4     1     2 3593507116
#
# $fullaug22
# layer value      count
# 1     1 -9999     311301
# 2     1     0 1031328484
# 3     1     1  177301457
# 4     1     2 3593507116
# 
# $fullaug23
# layer value      count
# 1     1 -9999     536136
# 2     1     0 1009720550
# 3     1     1  198684556
# 4     1     2 3593507116
# 
# $fullmay21
# layer value      count
# 1     1 -9999   34000392
# 2     1     0  929587709
# 3     1     1  245353141
# 4     1     2 3593507116
# 
# $fullmay22
# layer value      count
# 1     1 -9999   27702012
# 2     1     0  741330052
# 3     1     1  439909178
# 4     1     2 3593507116
# 
# $fullmay23
# layer value      count
# 1     1 -9999    1664916
# 2     1     0  842778473
# 3     1     1  364497853
# 4     1     2 3593507116

# $earlyaug21
# layer value      count
# 1     1 -9999   41881541
# 2     1     0 1009043657
# 3     1     1  158016044
# 4     1     2 3593507117
41881541/(41881541+1009043657+158016044+3593507117)*100
1009043657/(41881541+1009043657+158016044+3593507117)*100
158016044/(41881541+1009043657+158016044+3593507117)*100

# $earlyaug22
# layer value      count
# 1     1 -9999   21645919
# 2     1     0 1014182148
# 3     1     1  173113175
# 4     1     2 3593507116
21645919/(21645919+1014182148+173113175+3593507116)*100
1014182148/(21645919+1014182148+173113175+3593507116)*100
173113175/(21645919+1014182148+173113175+3593507116)*100

# $earlyaug23
# layer value      count
# 1     1 -9999  247769770
# 2     1     0  803826856
# 3     1     1  157344616
# 4     1     2 3593507117
247769770/(247769770+803826856+157344616+3593507117)*100
803826856/(247769770+803826856+157344616+3593507117)*100
157344616/(247769770+803826856+157344616+3593507117)*100

# $earlymay21
# layer value      count
# 1     1 -9999  152755037
# 2     1     0  842274690
# 3     1     1  213911515
# 4     1     2 3593507117
152755037/(152755037+842274690+213911515+3593507117)*100
842274690/(152755037+842274690+213911515+3593507117)*100
213911515/(152755037+842274690+213911515+3593507117)*100

# $earlymay22
# layer value      count
# 1     1 -9999  137972139
# 2     1     0  659755121
# 3     1     1  411213982
# 4     1     2 3593507117
137972139/(137972139+659755121+411213982+3593507117)*100
659755121/(137972139+659755121+411213982+3593507117)*100
411213982/(137972139+659755121+411213982+3593507117)*100

# $earlymay23
# layer value      count
# 1     1 -9999   19728673
# 2     1     0  828832302
# 3     1     1  360380267
# 4     1     2 3593507116
19728673/(19728673+828832302+360380267+3593507116)*100
828832302/(19728673+828832302+360380267+3593507116)*100
360380267/(19728673+828832302+360380267+3593507116)*100

library(tidyverse)

pond_data <- tribble(
  ~Month, ~Year, ~Timing, ~Clouded, ~Dry, ~Wet,
  "May", 2021, "Early", 3.2, 17.5, 4.5,
  "May", 2021, "Full", 0.7, 19.3, 5.1,
  "Aug", 2021, "Early", 0.9, 21.0, 3.3,
  "Aug", 2021, "Full", 0.004, 21.8, 3.4,
  "May", 2022, "Early", 2.9, 13.7, 8.6,
  "May", 2022, "Full", 0.6, 15.4, 9.2,
  "Aug", 2022, "Early", 0.45, 21.1, 3.6,
  "Aug", 2022, "Full", 0.006, 21.5, 3.7,
  "May", 2023, "Early", 0.4, 17.3, 7.5,
  "May", 2023, "Full", 0.03, 17.5, 7.6,
  "Aug", 2023, "Early", 5.2, 16.7, 3.3,
  "Aug", 2023, "Full", 0.01, 21.0, 4.1
)

pond_long <- pond_data %>%
  pivot_longer(cols = c(Clouded, Dry, Wet), names_to = "Category", values_to = "Percent") %>%
  mutate(
    # Create a proper date to sort by
    Date = lubridate::my(paste(Month, Year)),
    MonthYear = format(Date, "%b %Y"),
    Timing = factor(Timing, levels = c("Early", "Full")),
    Category = factor(Category, levels = c("Clouded", "Dry", "Wet"))
  ) %>%
  arrange(Date, Timing) %>%
  mutate(
    # Ensure MonthYear is a factor ordered by actual date
    MonthYear = factor(MonthYear, levels = unique(MonthYear))
  )

pond_long %>% 
  filter(Percent > 0.03) %>%
  ggplot(aes(x = MonthYear, y = Percent, fill = Category)) +
  geom_bar(stat = "identity") +
  geom_text(
    aes(label = paste0(round(Percent, 1), "%")),
    position = position_stack(vjust = 0.5),
    color = "white",
    size = 3
  ) +
  facet_wrap(~Timing, ncol = 1) +
  scale_fill_manual(values = c("Clouded" = "gray70", "Dry" = "tan3", "Wet" = "dodgerblue3")) +
  labs(
    title = "Classification proportions within historic wetland footprints",
    subtitle = "Historic wetland footprints comprise 25.2% of the PPR",
    x = NULL,
    y = "% class",
    fill = "Condition"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    panel.grid.major.x = element_blank(),
    strip.text = element_text(size = 16)
  )


