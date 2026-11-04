-- overall revenue and profit
SELECT
	COUNT(distinct order_id) as total_orders,
	COUNT(distinct customer_id) as total_customers,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(sum(profit),2) as total_profit,
	ROUND(SUM(profit)/SUM(sales),2) as total_profit_margin,
	ROUND(SUM(sales)/COUNT(distinct order_id),2) as average_order_value

FROM orders;

--monthly revenue trend with growth
with monthly_values as
(
SELECT 
	to_char(order_date,'mm') as month,
	to_char(order_date,'yyyy') as year,
	SUM(sales) as monthly_revenue,
	SUM(profit) as monthly_profit
	
	
FROM orders
GROUP BY to_char(order_date,'mm'),to_char(order_date,'yyyy')
)

SELECT 
	*,
	ROUND(monthly_revenue - lag(monthly_revenue) OVER (order by year,month),2) as growth_revenue,
	ROUND((monthly_revenue - lag(monthly_revenue) OVER (order by year,month))*100/lag(monthly_revenue) OVER (order by year,month),2) as revenue_growth_percentage
	
FROM monthly_values;

-- yearly revenue trend with growth

SELECT 
	to_char(order_date,'yyyy'),
	ROUND(sum(sales),2) as yearly_revenue,
	ROUND(lag(SUM(sales)) OVER (ORDER BY to_char(order_date,'yyyy')),2) as previous_year_revenue,
	ROUND(sum(sales) - lag(SUM(sales)) OVER (ORDER BY to_char(order_date,'yyyy')),2) as revenue_growth,
	(ROUND(sum(sales) - lag(SUM(sales)) OVER (ORDER BY to_char(order_date,'yyyy')),2))*100/lag(SUM(sales)) OVER (ORDER BY to_char(order_date,'yyyy')) as growth_percentage_revenue,
	ROUND(sum(profit),2) as monthly_profit,
	ROUND(lag(SUM(profit)) OVER (ORDER BY to_char(order_date,'yyyy')),2) as previous_year_profit,
	ROUND(sum(profit) - lag(SUM(profit)) OVER (ORDER BY to_char(order_date,'yyyy')),2) as profit_growth,
	(ROUND(sum(profit) - lag(SUM(profit)) OVER (ORDER BY to_char(order_date,'yyyy')),2))*100/lag(SUM(profit)) OVER (ORDER BY to_char(order_date,'yyyy')) as growth_percentage_revenue
	
FROM orders
GROUP BY to_char(order_date,'yyyy');

--revenue and profit by category

SELECT 
	category,
	COUNT(distinct order_id) as total_orders,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(SUM(profit),2) as total_profit,
	ROUND(SUM(profit)*100/SUM(sales),2) as profit_margin,
	ROUND(sum(sales)*100/SUM(sum(sales)) OVER (),2) as revenue_percentage
FROM orders
GROUP BY category
ORDER BY total_revenue desc;

-- bottom 5 subcategories by profit
SELECT 
	sub_category,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(SUM(profit),2) as total_profit,
	ROUND(SUM(profit)*100/SUM(sales),2) as profit_margin,
	ROUND(AVG(discount)*100,1) as discount_percentage
FROM orders
GROUP BY sub_category
ORDER BY total_profit
LIMIT 5;

--discount vs profit relationship
SELECT
	CASE 
		WHEN discount = 0 then 'no discount'
		WHEN discount <= 0.2 then 'low discount'
		WHEN discount <= 0.4 then 'medium discount'
		ELSE 'high discount'
	END as discount_margin,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(SUM(profit),2) as total_profit,
	ROUND(SUM(profit)*100/SUM(sales),2) as profit_margin
FROM orders
GROUP BY discount_margin;

-- top 10 customers by revenue
SELECT
	customer_id,
	segment,
	COUNT(distinct order_id) as total_orders,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(SUM(profit),2) as total_profit,
	ROUND(SUM(profit)*100/SUM(sales),2) as profit_margin
FROM orders
GROUP By customer_id,segment
ORDER BY total_revenue desc
limit 10;

-- regional performance

SELECT
	region,
	COUNT(distinct order_id) as total_orders,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(SUM(profit),2) as total_profit,
	ROUND(SUM(profit)*100/SUM(sales),2) as profit_margin
FROM orders
GROUP By region
ORDER BY total_revenue desc;

-- segment performance

SELECT
	segment,
	COUNT(distinct order_id) as total_orders,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(SUM(profit),2) as total_profit,
	ROUND(SUM(profit)*100/SUM(sales),2) as profit_margin
FROM orders
GROUP By segment
ORDER BY total_revenue desc;

-- top 2 products per category
SELECT 
	product_name,
	category,
	revenue
FROM
	(
		SELECT 
			product_name,
			category,
			ROUND(SUM(sales),2) as revenue,
			RANK() OVER (partition by category order by SUM(sales) desc) as rnk
		FROM orders
		GROUP BY category,product_name
)
where rnk <= 2;

-- percentage of orders returned

SELECT (100*COUNT(r.order_id)::numeric/COUNT(o.order_id)) as return_percentage
FROM orders o
LEFT JOIN returns r
ON o.order_id = r.order_id;

--shipping performance

SELECT 
	ship_mode,
	COUNT(DISTINCT order_id) as total_orders,
	ROUND(AVG(ship_date - order_date),2) as average_shipping_days
FROM orders
GROUP BY ship_mode;

--state level profitability

SELECT
	state_province,
	COUNT(distinct order_id) as total_orders,
	ROUND(SUM(sales),2) as total_revenue,
	ROUND(SUM(profit),2) as total_profit,
	ROUND(SUM(profit)*100/SUM(sales),2) as profit_margin_percentage
FROM orders
GROUP By state_province
ORDER BY total_revenue desc;

--repeat customers
SELECT
	customer_id,
	COUNT(distinct order_id) as no_orders
FROM orders
GROUP BY customer_id
HAVING COUNT(distinct order_id) > 1;

-- percentage of customers who are repeat customers
SELECT 
	ROUND(COUNT(*)::numeric/(SELECT count(distinct customer_id) from orders)*100,2) as percentage_repeat_customers
FROM
(
SELECT
	customer_id,
	COUNT(distinct order_id) as no_orders
FROM orders
GROUP BY customer_id
HAVING COUNT(distinct order_id) > 1
) as  repeat_customers;

-- frequency of purchase by customer

SELECT
	*,
	CASE 
		WHEN average_days_between_orders is null then 'not a repeating customer'
		WHEN average_days_between_orders between 0 and 100 then 'frequent customer'
		WHEN average_days_between_orders <= 200 then 'occasional customer'
		ELSE 'infrequent customer'
	END as order_frequency
FROM
(
SELECT 
	customer_id,
	ROUND(AVG(duration),2) as average_days_between_orders
FROM
(
SELECT 
	customer_id,
	order_id,
	order_date,
	LAG(order_date) OVER(partition by customer_id ORDER BY order_date) as  last_order,
	order_date - LAG(order_date) OVER(partition by customer_id ORDER BY order_date) as duration
FROM orders
GROUP BY customer_id,order_date,order_id
)
GROUP BY customer_id
);

-- average revenue per customer
SELECT
	customer_id,
	segment,
	COUNT(distinct order_id) as total_orders,
	ROUND(avg(sales),2) as average_revenue,
	ROUND(avg(profit),2) as total_profit
FROM orders
GROUP By customer_id,segment
ORDER BY average_revenue desc

