# Load packages 
library(tidyverse)
library(afex)
library(emmeans)
library(stats)
library(reshape2)
library(pastecs)
library(MOTE)
library(janitor)

set.seed(21)

# Replication data --------------------------------------------------------------------

# Load rep_data

rep_data <- read_csv("10m_sprint_time.csv") %>%
  clean_names() %>%
  rowwise() %>%
  drop_na()
head(rep_data)

# Prepare rep_data

anova_rep_data <- rep_data %>%
  pivot_longer(cols = c(con:cho),
               names_to = "condition",
               values_to = "sprint_10m") 

anova_rep_data$condition <-  as.factor(anova_rep_data$condition)
anova_rep_data$participant <-  as.factor(anova_rep_data$participant)

## Descriptives ---------------------

summary_rep_data <- anova_rep_data %>%
  group_by(condition) %>%
  summarise(count = n (),
            mean = mean(sprint_10m),
            sd = sd(sprint_10m))
summary_rep_data

### Plots ---------------------------------------------------------------------------

### Histogram 

# Prepare anova_rep_data
hist_dat <- anova_rep_data %>%
  select(sprint_10m)

hist_dat$id <- 1:nrow(hist_dat)
hist_dat <- melt(hist_dat, id.vars = "id")

# Plot histogram
hist <- ggplot(data = hist_dat, aes(x = value, fill = variable)) +
  geom_histogram(color = "black", fill = "white",
                 bins = 15) +
  facet_wrap( ~ variable) +
  scale_x_continuous(name = "10m Sprint Time (seconds)")
hist

### Q-Q plots 

ggplot(anova_rep_data, aes(sample = sprint_10m)) +
  geom_qq() +
  geom_qq_line() +
  scale_x_continuous(name = "Observed Value") +
  scale_y_continuous(name = "Expected Normal")


### Boxplot 

ggplot(anova_rep_data, aes(x = condition, y = sprint_10m)) +
  geom_violin(trim = FALSE) +
  geom_boxplot(width = .2)

## Replication ANOVA ----------------------------------------------------------------------------

##afex::aov_4(continuous_var ~ condition_var + (RM_var|id_var)

anova_rep_data_afx <- afex::aov_4(
  sprint_10m ~ condition + (condition | participant),
  data = anova_rep_data,
  anova_table = list(correction = "GG", es = "pes")
) # using Greenhouse Geisser sphercity correction and partial eta squared
anova_rep_data_afx

summary(anova_rep_data_afx)


### Assumption checking ---------

# Normality test

shapiro.test(anova_rep_data_afx$lm$residuals) # residuals are not normally distributed

anova_rep_data %>% 
  group_by(condition) %>% 
  rstatix::shapiro_test(sprint_10m)

### Post hoc contrasts ----------------------------------------------------------------------------

anova_rep_data_emm <-
  emmeans::emmeans(anova_rep_data_afx, ~ condition, model = "multivariate")
anova_rep_data_emm

posthocresults <- pairs(anova_rep_data_emm, adjust = "bon") %>%
  broom::tidy(conf.int = T)
posthocresults

## Replication effect size ----------------------------------------------------------------------------

pes_rep <- eta.F(
  dfm = anova_rep_data_afx$anova_table$`num Df`,
  dfe = anova_rep_data_afx$anova_table$`den Df`,
  Fvalue = anova_rep_data_afx$anova_table$F,
  a = 0.05) %>%
  as.data.frame() %>%
  select(eta, etalow, etahigh) %>%
  mutate(study_id = c("Replication study")) # add identifier
pes_rep

# Original data ------------------
## Data prep 

# Load orig_data

orig_data <- read_csv("original_sprint_data.csv") %>%
  clean_names() %>%
  rename(con = control,
          pla = placebo,
          cho = maltodextrin)
head(orig_data)

# Prepare orig_data

anova_orig_data <- orig_data %>%
  pivot_longer(cols = c(con:cho),
               names_to = "condition",
               values_to = "sprint_10m") 

anova_orig_data$condition <-  as.factor(anova_orig_data$condition)
anova_orig_data$participant <-  as.factor(anova_orig_data$participant)


## Descriptives ---------------------

summary_orig_data <- anova_orig_data %>%
  group_by(condition) %>%
  summarise(count = n (),
            mean = mean(sprint_10m),
            sd = sd(sprint_10m))
summary_orig_data

# Boxplot 

ggplot(anova_orig_data, aes(x = condition, y = sprint_10m)) +
  geom_violin(trim = FALSE) +
  geom_boxplot(width = .2)

## Original ANOVA  ----------------------------------------------------------------------------

##afex::aov_4(continuous_var ~ condition_var + (RM_var|id_var)

anova_orig_data_afx <- afex::aov_4(
  sprint_10m ~ condition  + (condition | participant),
  data = anova_orig_data,
  anova_table = list(correction = "GG", es = "pes")
) # using Greenhouse Geisser sphercity correction and partial eta squared
anova_orig_data_afx

summary(anova_orig_data_afx)

### Assumption checking ---------

# Normality test

shapiro.test(anova_orig_data_afx$lm$residuals) 

anova_orig_data %>% 
  group_by(condition) %>% 
  rstatix::shapiro_test(sprint_10m)

## Original effect size ----------------------------------------------------------------------------

pes_orig <- eta.F(
  dfm = anova_orig_data_afx$anova_table$`num Df`,
  dfe = anova_orig_data_afx$anova_table$`den Df`,
  Fvalue = anova_orig_data_afx$anova_table$F,
  a = 0.05) %>%
  as.data.frame() %>%
  select(eta, etalow, etahigh) %>%
  mutate(study_id = c("Original study")) # add identifier
pes_orig

# Replication test -----

pes_rep_eta = anova_rep_data_afx$anova_table$pes
df_rep = anova_rep_data_afx$anova_table$`den Df`
pes_orig_eta = anova_orig_data_afx$anova_table$pes
df_ori = 22

rho_ori = 2 * sqrt(pes_orig_eta) - 1
rho_rep = 2 * sqrt(pes_rep_eta) - 1

rep_test = TOSTER::compare_cor(r1 = rho_ori,
                               df1 = df_ori,
                               r2 = rho_rep,
                               df2 = df_rep,
                               alternative = "greater")
rep_test

# Forest plot ---------

## Labels for sprint_10m forest plot -------------
label_rep <- "0.28 [0.03, 0.53]"
label_ori <- "0.47 [0.09, 0.72]"

## Join rep_datasets -----------------
plot <-
  merge(
    pes_orig,
    pes_rep,
    by = c("eta", "etalow", "etahigh", "study_id"),
    all = TRUE
  )

## Plot -----------------------------
ggplot(plot,
       aes(
         y = study_id,
         x = eta,
         xmin = etalow,
         xmax = etahigh
       )) +
  ggtitle("Partial eta squared [95% CI]") +
  geom_point() +
  geom_errorbarh(height = .1) +
  geom_vline(
    xintercept = 0,
    color = 'black',
    linetype = 'dashed',
    alpha = .4
  ) +
  theme_minimal() +
  scale_x_continuous(name = "Observed Effect Size", limits = c(-1, 2.2)) +
  scale_y_discrete(name = "") +
  annotate("text",
           x = 1.8,
           y = 2,
           label = label_rep) +
  annotate("text",
           x = 1.8,
           y = 1,
           label = label_ori) +
  theme(
    axis.line.x = element_line(color = "black"),
    axis.text.y = element_text(size = 11),
    axis.title.x = element_text(size = 11),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank(),
    plot.title = element_text(hjust = 0.94),
    panel.background = element_blank()
  )

