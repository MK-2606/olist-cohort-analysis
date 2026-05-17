SELECT
  cohort_month,
  cohort_size,
  MAX(IF(months_since_first = 0,  retention_pct, NULL)) AS month_0,
  MAX(IF(months_since_first = 1,  retention_pct, NULL)) AS month_1,
  MAX(IF(months_since_first = 2,  retention_pct, NULL)) AS month_2,
  MAX(IF(months_since_first = 3,  retention_pct, NULL)) AS month_3,
  MAX(IF(months_since_first = 4,  retention_pct, NULL)) AS month_4,
  MAX(IF(months_since_first = 5,  retention_pct, NULL)) AS month_5,
  MAX(IF(months_since_first = 6,  retention_pct, NULL)) AS month_6,
  MAX(IF(months_since_first = 7,  retention_pct, NULL)) AS month_7,
  MAX(IF(months_since_first = 8,  retention_pct, NULL)) AS month_8,
  MAX(IF(months_since_first = 9,  retention_pct, NULL)) AS month_9,
  MAX(IF(months_since_first = 10, retention_pct, NULL)) AS month_10,
  MAX(IF(months_since_first = 11, retention_pct, NULL)) AS month_11,
  MAX(IF(months_since_first = 12, retention_pct, NULL)) AS month_12

FROM `olist-cohort-analysis.olist_analysis.retention_matrix`
WHERE cohort_size >= 50
GROUP BY cohort_month, cohort_size
ORDER BY cohort_month