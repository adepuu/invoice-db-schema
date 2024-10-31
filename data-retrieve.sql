-- 0. Get invoice details with invoice ID
SELECT * FROM get_invoice_details('INV-2024100101');

-- 1. Basic Invoice Summary with Customer and Seller Details using historical data
SELECT
    i.invoice_id,
    i.purchase_date,
    b.buyer_name,
    b.phone_number,
    CONCAT(b.address_street, ', ', b.address_district, ', ', b.address_city, ', ', b.address_province, ' ', b.postal_code) as delivery_address,
    COALESCE(sh.seller_name, s.seller_name) as seller_name,
    i.shipping_method,
    i.payment_method,
    i.shipping_cost,
    i.shipping_insurance,
    i.service_fee,
    i.application_fee,
    COALESCE(p.name, 'No Promo') as promo_name,
    CASE
        WHEN p.deduction_type = 1 THEN CONCAT('Rp ', p.amount::text)
        WHEN p.deduction_type = 2 THEN CONCAT(p.amount::text, '%')
        END as promo_value
FROM
    public.invoices i
        JOIN public.buyers b ON i.buyer_id = b.buyer_id
        JOIN public.sellers s ON i.seller_id = s.seller_id
        LEFT JOIN public.sellers_history sh ON i.seller_id = sh.seller_id
        AND i.reference_time <@ sh.system_period
        LEFT JOIN public.promo_usage pu ON i.invoice_id = pu.invoice_id
        LEFT JOIN public.promo p ON pu.promo_id = p.promo_id;

-- 2. Detailed Invoice Items with Historical Product Information
WITH invoice_totals AS (
    SELECT
        invoice_id,
        SUM(subtotal) as total_items_cost
    FROM
        public.invoice_items
    GROUP BY
        invoice_id
)
SELECT
    i.invoice_id,
    i.purchase_date,
    b.buyer_name,
    COALESCE(sh.seller_name, s.seller_name) as seller_name,
    COALESCE(ph.product_name, p.product_name) as product_name,
    ii.quantity,
    TO_CHAR(ii.unit_price, 'FM999,999,999') as unit_price,
    TO_CHAR(ii.subtotal, 'FM999,999,999') as subtotal,
    TO_CHAR(i.shipping_cost, 'FM999,999,999') as shipping_cost,
    TO_CHAR(i.shipping_insurance, 'FM999,999,999') as insurance_cost,
    TO_CHAR(i.service_fee, 'FM999,999,999') as service_fee,
    TO_CHAR(i.application_fee, 'FM999,999,999') as application_fee,
    TO_CHAR(it.total_items_cost, 'FM999,999,999') as total_items_cost,
    COALESCE(pr.name, 'No Promo') as promo_name,
    CASE
        WHEN pr.deduction_type = 1 THEN pr.amount  -- Fixed amount
        WHEN pr.deduction_type = 2 THEN (it.total_items_cost * pr.amount / 100)  -- Percentage
        ELSE 0
        END as promo_discount,
    TO_CHAR(
            it.total_items_cost + i.shipping_cost + i.shipping_insurance + i.service_fee + i.application_fee -
            CASE
                WHEN pr.deduction_type = 1 THEN pr.amount  -- Fixed amount
                WHEN pr.deduction_type = 2 THEN (it.total_items_cost * pr.amount / 100)  -- Percentage
                ELSE 0
                END,
            'FM999,999,999'
    ) as grand_total
FROM
    public.invoices i
        JOIN public.buyers b ON i.buyer_id = b.buyer_id
        JOIN public.sellers s ON i.seller_id = s.seller_id
        LEFT JOIN public.sellers_history sh ON i.seller_id = sh.seller_id
        AND i.reference_time <@ sh.system_period
        JOIN public.invoice_items ii ON i.invoice_id = ii.invoice_id
        JOIN public.products p ON ii.product_id = p.product_id
        LEFT JOIN public.products_history ph ON ii.product_id = ph.product_id
        AND i.reference_time <@ ph.system_period
        JOIN invoice_totals it ON i.invoice_id = it.invoice_id
        LEFT JOIN public.promo_usage pu ON i.invoice_id = pu.invoice_id
        LEFT JOIN public.promo pr ON pu.promo_id = pr.promo_id
ORDER BY
    i.invoice_id, COALESCE(ph.product_name, p.product_name);

-- 3. Summary of Sales by Seller with Historical Data
SELECT
    COALESCE(sh.seller_name, s.seller_name) as seller_name,
    COUNT(DISTINCT i.invoice_id) as total_orders,
    COUNT(ii.invoice_item_id) as total_items_sold,
    TO_CHAR(SUM(ii.subtotal), 'FM999,999,999') as total_sales_amount,
    TO_CHAR(AVG(ii.subtotal), 'FM999,999,999') as average_order_value,
    STRING_AGG(DISTINCT COALESCE(ph.product_name, p.product_name), ', ') as products_sold
FROM
    public.sellers s
        LEFT JOIN public.sellers_history sh ON s.seller_id = sh.seller_id
        JOIN public.invoices i ON s.seller_id = i.seller_id
        AND (sh.system_period IS NULL OR i.reference_time <@ sh.system_period)
        JOIN public.invoice_items ii ON i.invoice_id = ii.invoice_id
        JOIN public.products p ON ii.product_id = p.product_id
        LEFT JOIN public.products_history ph ON ii.product_id = ph.product_id
        AND i.reference_time <@ ph.system_period
GROUP BY
    s.seller_id, COALESCE(sh.seller_name, s.seller_name)
ORDER BY
    total_sales_amount DESC;

-- 4. Product Sales Analysis with Historical Data
SELECT
    COALESCE(ph.product_name, p.product_name) as product_name,
    COUNT(ii.invoice_item_id) as times_sold,
    SUM(ii.quantity) as total_units_sold,
    TO_CHAR(SUM(ii.subtotal), 'FM999,999,999') as total_revenue,
    TO_CHAR(AVG(ii.unit_price), 'FM999,999,999') as average_selling_price,
    COUNT(DISTINCT i.buyer_id) as unique_buyers,
    MIN(i.purchase_date) as first_sale_date,
    MAX(i.purchase_date) as last_sale_date
FROM
    public.products p
        LEFT JOIN public.products_history ph ON p.product_id = ph.product_id
        LEFT JOIN public.invoice_items ii ON p.product_id = ii.product_id
        LEFT JOIN public.invoices i ON ii.invoice_id = i.invoice_id
        AND (ph.system_period IS NULL OR i.reference_time <@ ph.system_period)
GROUP BY
    p.product_id, COALESCE(ph.product_name, p.product_name)
ORDER BY
    total_units_sold DESC;

-- 5. Price Change Analysis for Products
SELECT
    p.product_id,
    p.product_name as current_name,
    ph.product_name as historical_name,
    ph.price as historical_price,
    p.price as current_price,
    p.price - ph.price as price_difference,
    ROUND(((p.price - ph.price) / ph.price * 100), 2) as price_change_percentage,
    ph.system_period as valid_period
FROM
    public.products p
        JOIN public.products_history ph ON p.product_id = ph.product_id
WHERE
    p.price != ph.price
ORDER BY
    p.product_id, ph.system_period;

