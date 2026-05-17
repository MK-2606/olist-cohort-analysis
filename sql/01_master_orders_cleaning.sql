-- =========================================================
-- Project : Olist Customer Cohort Analysis
-- Author  : Mansi Kumari
-- Tool    : Google BigQuery (Standard SQL)
-- File    : 01_master_orders_cleaning.sql
-- Purpose : Filter delivered orders, join customers +
--           payments, create master_orders base table
-- Output  : olist_analysis.master_orders
-- =========================================================

SELECT
  o.order_id,
  c.customer_unique_id,
  c.customer_city,
  c.customer_state,
  DATE(o.order_purchase_timestamp) AS order_date,
  FORMAT_DATE('%Y-%m', o.order_purchase_timestamp) AS order_month,
  o.order_status,
  ROUND(SUM(p.payment_value), 2) AS order_revenue

FROM `olist-cohort-analysis.olist_raw.Orders` AS o

JOIN `olist-cohort-analysis.olist_raw.customers` AS c
  ON o.customer_id = c.customer_id

JOIN `olist-cohort-analysis.olist_raw.payments` AS p
  ON o.order_id = p.order_id

WHERE
  o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL

GROUP BY 1, 2, 3, 4, 5, 6, 7;
