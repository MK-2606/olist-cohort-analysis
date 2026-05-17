SELECT
  customer_unique_id,
  MIN(order_month) AS cohort_month,
  MIN(order_date)  AS first_order_date,
  COUNT(DISTINCT order_id)   AS total_orders,
  ROUND(SUM(order_revenue), 2) AS total_spend

FROM `olist-cohort-analysis.olist_analysis.master_orders`

GROUP BY customer_unique_id;
