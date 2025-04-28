# 載入必要的套件
library(dplyr)
library(readxl)
library(seminr)

# 匯入 Excel 檔案
data <- read_excel("../data/data_sample.xlsx")

# 1. 確定變數欄位
submission_diff_cols <- colnames(data)[grepl("_Submission_Diff$", colnames(data))]  # 繳交時間差
submission_cols <- grep("HW_Submissions", colnames(data), value = TRUE)            # 繳交次數
score_cols <- colnames(data)[grepl("_Score$", colnames(data))]                     # 作業成績

# 2. 排除未繳交的資料（僅保留非空白資料）
data[submission_diff_cols] <- lapply(data[submission_diff_cols], function(x) {
  x[is.na(x)] <- NA  # 空白表示未繳交，保留現有的0或負值
  return(x)
})
data[submission_cols] <- lapply(data[submission_cols], function(x) {
  x[is.na(x)] <- NA
  return(x)
})
data[score_cols] <- lapply(data[score_cols], function(x) {
  x[is.na(x)] <- NA
  return(x)
})

# 3. 計算平均繳交次數、作業成績和繳交時間差
data <- data %>%
  mutate(
    avg_submission_count = rowMeans(select(., all_of(submission_cols)), na.rm = TRUE),  # 平均繳交次數
    avg_score = rowMeans(select(., all_of(score_cols)), na.rm = TRUE),                 # 平均作業成績
    avg_submission_diff = rowMeans(select(., all_of(submission_diff_cols)), na.rm = TRUE)  # 平均繳交時間差
  )

# 4. 定義測量模型
research_mm <- constructs(
  # 第一階段構念
  reflective("學習風格", single_item("Learning_Score")),
  
  # 第二階段構念
  reflective("作業繳交次數", single_item("avg_submission_count")),  # 單一變數：平均次數
  reflective("作業繳交時間", single_item("avg_submission_diff")),   # 單一變數：平均繳交時間差
  
  # 第三階段構念
  reflective("作業成績", single_item("avg_score")),               # 單一變數：平均作業成績
  reflective("學期成績", single_item("Final_Score"))
)

# 5. 定義結構模型
research_sm <- relationships(
  paths(from = c("學習風格"), to = c("作業繳交次數", "作業繳交時間")),  # 第一階段 → 第二階段
  paths(from = c("作業繳交次數", "作業繳交時間"), to = c("作業成績", "學期成績"))         # 第二階段 → 第三階段
)

# 6. 執行 PLS-SEM 分析
simple_model <- estimate_pls(
  data = data,
  measurement_model = research_mm,
  structural_model = research_sm
)

# 7. 查看模型摘要結果
summary_simple <- summary(simple_model)
print(summary_simple)

# 查看平均作業繳交行為描述行統計
summary(data[, c("avg_submission_count", "avg_submission_diff","avg_score")])

# 8. 引導抽樣模型 (Bootstrap)
boot_model <- bootstrap_model(
  seminr_model = simple_model,
  nboot = 10000,
  cores = parallel::detectCores(),
  seed = 123
)

# 引導抽樣模型摘要
summary_boot <- summary(boot_model, alpha = 0.05)
print(summary_boot)

# 設定自由度
df <- nrow(data) - length(simple_model$constructs)  # 樣本數 - 構念數量

# 提取 t 值
t_values <- summary_boot$bootstrapped_paths[, "T Stat."]

# 計算 p 值（雙尾檢定）
p_values <- 2 * stats::pt(abs(t_values), df, lower.tail = FALSE)

# 整合 p 值到結果中
result_with_pvalues <- cbind(
  summary_boot$bootstrapped_paths,
  p_value = p_values
)

# 查看結果
print(result_with_pvalues)

# 獨立樣本 t 檢定
t.test(avg_submission_count ~ Gender, data = data, var.equal = TRUE)

# 計算各組的統計數據
summary_table <- data %>%
  group_by(Gender) %>%
  summarise(
    人數 = n(),
    平均數 = mean(avg_submission_count),
    標準差 = sd(avg_submission_count)
  )

# 執行 t 檢定
t_test_result <- t.test(avg_submission_count ~ Gender, data = data, var.equal = TRUE)

# 將 t 檢定結果添加到表格
summary_table <- summary_table %>%
  mutate(
    t值 = ifelse(row_number() == 1, t_test_result$statistic, NA),
    單尾顯著性 = ifelse(row_number() == 1, t_test_result$p.value / 2, NA)
  )

# 顯示結果
summary_table