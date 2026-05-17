-- =========================================================
-- Project : Olist Customer Cohort Analysis
-- Author  : Mansi Kumari
-- Tool    : Google BigQuery (Standard SQL)
-- File    : 05_kpi_queries.sql
-- Purpose : 10 business KPIs — churn, repeat window,
--           revenue split, acquisition, AOV, seasonal
--           cohorts, state analysis, DENSE_RANK, NTILE
--           segmentation, payment method breakdown
-- Output  : Exported as CSVs for Python visualisation
-- =========================================================

-- KPI 1

SELECT
  cohort_month,
  COUNT(customer_unique_id)                              AS cohort_size,
  COUNTIF(total_orders = 1)                             AS one_time_buyers,
  COUNTIF(total_orders > 1)                             AS repeat_buyers,
  ROUND(COUNTIF(total_orders = 1)
    / COUNT(customer_unique_id) * 100, 1)               AS churn_rate_pct,
  ROUND(COUNTIF(total_orders > 1)
    / COUNT(customer_unique_id) * 100, 1)               AS repeat_rate_pct
FROM `olist-cohort-analysis.olist_analysis.cohort_base`
GROUP BY cohort_month
ORDER BY cohort_month;


-- KPI 2

WITH ranked_orders AS (
  SELECT
    customer_unique_id,
    order_id,
    order_date,
    ROW_NUMBER() OVER(
      PARTITION BY customer_unique_id
      ORDER BY order_date ASC
    ) AS purchase_rank
  FROM `olist-cohort-analysis.olist_analysis.master_orders`
),

purchase_pairs AS (
  SELECT
    first_p.customer_unique_id,
    first_p.order_date  AS first_purchase_date,
    second_p.order_date AS second_purchase_date,
    DATE_DIFF(second_p.order_date, first_p.order_date, DAY) AS days_gap
  FROM ranked_orders first_p
  JOIN ranked_orders second_p
    ON  first_p.customer_unique_id = second_p.customer_unique_id
    AND first_p.purchase_rank = 1
    AND second_p.purchase_rank = 2
)

SELECT
  COUNT(*)                                        AS repeat_customers,
  ROUND(AVG(days_gap), 1)                         AS avg_days_to_repurchase,
  APPROX_QUANTILES(days_gap, 100)[OFFSET(50)]     AS median_days,
  APPROX_QUANTILES(days_gap, 100)[OFFSET(25)]     AS p25_days,
  APPROX_QUANTILES(days_gap, 100)[OFFSET(75)]     AS p75_days
FROM purchase_pairs;


-- KPI 3

WITH customer_segments AS (
  SELECT
    m.customer_unique_id,
    m.order_id,
    m.order_revenue,
    CASE
      WHEN cb.total_orders = 1 THEN 'one_time'
      ELSE 'repeat'
    END AS customer_type
  FROM `olist-cohort-analysis.olist_analysis.master_orders` m
  JOIN `olist-cohort-analysis.olist_analysis.cohort_base` cb
    ON m.customer_unique_id = cb.customer_unique_id
)

SELECT
  customer_type,
  COUNT(DISTINCT customer_unique_id)              AS customer_count,
  COUNT(DISTINCT order_id)                        AS order_count,
  ROUND(SUM(order_revenue), 2)                    AS total_revenue,
  ROUND(SUM(order_revenue)
    / SUM(SUM(order_revenue)) OVER() * 100, 1)   AS revenue_share_pct,
  ROUND(AVG(order_revenue), 2)                    AS avg_order_value
FROM customer_segments
GROUP BY customer_type;


-- KPI 4

SELECT
  cohort_month                                    AS acquisition_month,
  COUNT(customer_unique_id)                       AS new_customers,
  SUM(total_spend)                                AS cohort_first_month_revenue,
  ROUND(AVG(total_spend), 2)                      AS avg_first_order_value,
  SUM(COUNT(customer_unique_id)) OVER(
    ORDER BY cohort_month
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )                                               AS cumulative_customers
FROM `olist-cohort-analysis.olist_analysis.cohort_base`
GROUP BY cohort_month
ORDER BY cohort_month;


-- KPI 5

SELECT
  cb.cohort_month,
  COUNT(DISTINCT m.order_id)                      AS total_orders,
  COUNT(DISTINCT m.customer_unique_id)            AS active_customers,
  ROUND(SUM(m.order_revenue), 2)                  AS total_revenue,
  ROUND(SUM(m.order_revenue)
    / COUNT(DISTINCT m.order_id), 2)              AS avg_order_value,
  ROUND(SUM(m.order_revenue)
    / COUNT(DISTINCT m.customer_unique_id), 2)    AS revenue_per_customer
FROM `olist-cohort-analysis.olist_analysis.master_orders` m
JOIN `olist-cohort-analysis.olist_analysis.cohort_base` cb
  ON m.customer_unique_id = cb.customer_unique_id
GROUP BY cb.cohort_month
HAVING COUNT(DISTINCT m.customer_unique_id) >= 50
ORDER BY cb.cohort_month;


-- KPI 6

WITH cohort_season AS (
  SELECT
    rm.cohort_month,
    rm.cohort_size,
    rm.months_since_first,
    rm.retention_pct,
    CASE
      WHEN SUBSTR(rm.cohort_month, 6, 2) IN ('11','12')
        THEN 'holiday (Nov–Dec)'
      WHEN SUBSTR(rm.cohort_month, 6, 2) IN ('06','07','08')
        THEN 'mid-year (Jun–Aug)'
      ELSE 'regular'
    END AS season
  FROM `olist-cohort-analysis.olist_analysis.retention_matrix` rm
  WHERE rm.cohort_size >= 50
)

SELECT
  season,
  months_since_first,
  COUNT(DISTINCT cohort_month)                    AS cohorts_in_season,
  ROUND(AVG(retention_pct), 2)                    AS avg_retention_pct
FROM cohort_season
WHERE months_since_first BETWEEN 1 AND 6
GROUP BY season, months_since_first
ORDER BY months_since_first, season;


-- KPI 7

WITH state_customers AS (
  SELECT
    m.customer_state,
    m.customer_unique_id,
    cb.total_orders
  FROM `olist-cohort-analysis.olist_analysis.master_orders` m
  JOIN `olist-cohort-analysis.olist_analysis.cohort_base` cb
    ON m.customer_unique_id = cb.customer_unique_id
  GROUP BY m.customer_state, m.customer_unique_id, cb.total_orders
)

SELECT
  customer_state,
  COUNT(customer_unique_id)                       AS total_customers,
  COUNTIF(total_orders > 1)                       AS repeat_customers,
  ROUND(COUNTIF(total_orders > 1)
    / COUNT(customer_unique_id) * 100, 1)         AS repeat_rate_pct,
  ROUND(AVG(total_orders), 2)                     AS avg_orders_per_customer
FROM state_customers
GROUP BY customer_state
HAVING COUNT(customer_unique_id) >= 100
ORDER BY repeat_rate_pct DESC
LIMIT 15;


-- KPI 8

WITH customer_spend AS (
  SELECT
    customer_unique_id,
    COUNT(DISTINCT order_id)                      AS total_orders,
    ROUND(SUM(order_revenue), 2)                  AS lifetime_spend,
    ROUND(AVG(order_revenue), 2)                  AS avg_order_value,
    MIN(order_date)                               AS first_purchase,
    MAX(order_date)                               AS last_purchase,
    DATE_DIFF(MAX(order_date), MIN(order_date), DAY) AS customer_lifespan_days
  FROM `olist-cohort-analysis.olist_analysis.master_orders`
  GROUP BY customer_unique_id
)

SELECT
  customer_unique_id,
  total_orders,
  lifetime_spend,
  avg_order_value,
  customer_lifespan_days,
  DENSE_RANK() OVER(ORDER BY lifetime_spend DESC) AS spend_rank
FROM customer_spend
ORDER BY spend_rank
LIMIT 100;


-- KPI 9

WITH customer_spend AS (
  SELECT
    customer_unique_id,
    ROUND(SUM(order_revenue), 2)                  AS lifetime_spend,
    COUNT(DISTINCT order_id)                      AS total_orders
  FROM `olist-cohort-analysis.olist_analysis.master_orders`
  GROUP BY customer_unique_id
),

with_tier AS (
  SELECT
    customer_unique_id,
    lifetime_spend,
    total_orders,
    NTILE(4) OVER(ORDER BY lifetime_spend ASC)    AS spend_quartile
  FROM customer_spend
)

SELECT
  spend_quartile,
  CASE spend_quartile
    WHEN 1 THEN 'Bronze  (bottom 25%)'
    WHEN 2 THEN 'Silver  (25–50%)'
    WHEN 3 THEN 'Gold    (50–75%)'
    WHEN 4 THEN 'Platinum (top 25%)'
  END                                             AS segment_label,
  COUNT(customer_unique_id)                       AS customer_count,
  ROUND(MIN(lifetime_spend), 2)                   AS min_spend,
  ROUND(MAX(lifetime_spend), 2)                   AS max_spend,
  ROUND(AVG(lifetime_spend), 2)                   AS avg_spend,
  ROUND(SUM(lifetime_spend), 2)                   AS total_segment_revenue,
  ROUND(SUM(lifetime_spend)
    / SUM(SUM(lifetime_spend)) OVER() * 100, 1)  AS revenue_share_pct
FROM with_tier
GROUP BY spend_quartile
ORDER BY spend_quartile;


-- KPI 10

SELECT
  cb.cohort_month,
  p.payment_type,
  COUNT(DISTINCT p.order_id)                      AS orders_count,
  ROUND(SUM(p.payment_value), 2)                  AS total_payment_value,
  ROUND(AVG(p.payment_value), 2)                  AS avg_payment_value,
  ROUND(COUNT(DISTINCT p.order_id)
    / SUM(COUNT(DISTINCT p.order_id)) OVER(
        PARTITION BY cb.cohort_month
      ) * 100, 1)                                 AS pct_of_cohort_orders
FROM `olist-cohort-analysis.olist_raw.payments` p
JOIN `olist-cohort-analysis.olist_raw.Orders` o
  ON p.order_id = o.order_id
JOIN `olist-cohort-analysis.olist_raw.customers` c
  ON o.customer_id = c.customer_id
JOIN `olist-cohort-analysis.olist_analysis.cohort_base` cb
  ON c.customer_unique_id = cb.customer_unique_id
WHERE o.order_status = 'delivered'
GROUP BY cb.cohort_month, p.payment_type
ORDER BY cb.cohort_month, orders_count DESC;
