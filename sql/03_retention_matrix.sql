WITH tagged_orders AS (
  SELECT
    m.customer_unique_id,
    m.order_id,
    m.order_month,
    cb.cohort_month,
    DATE_DIFF(
      DATE(PARSE_DATE('%Y-%m', m.order_month)),
      DATE(PARSE_DATE('%Y-%m', cb.cohort_month)),
      MONTH
    ) AS months_since_first
  FROM `olist-cohort-analysis.olist_analysis.master_orders` AS m
  JOIN `olist-cohort-analysis.olist_analysis.cohort_base` AS cb
    ON m.customer_unique_id = cb.customer_unique_id
),

cohort_sizes AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT customer_unique_id) AS cohort_size
  FROM `olist-cohort-analysis.olist_analysis.cohort_base`
  GROUP BY cohort_month
),

monthly_active AS (
  SELECT
    cohort_month,
    months_since_first,
    COUNT(DISTINCT customer_unique_id) AS active_customers
  FROM tagged_orders
  GROUP BY cohort_month, months_since_first
)

SELECT
  ma.cohort_month,
  cs.cohort_size,
  ma.months_since_first,
  ma.active_customers,
  ROUND(ma.active_customers / cs.cohort_size * 100, 1) AS retention_pct
FROM monthly_active AS ma
JOIN cohort_sizes AS cs
  ON ma.cohort_month = cs.cohort_month
ORDER BY ma.cohort_month, ma.months_since_first;
