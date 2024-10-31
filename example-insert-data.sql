-- Clear existing data (if any)
DELETE
FROM public.promo_usage;
DELETE
FROM public.invoice_items;
DELETE
FROM public.invoices;
DELETE
FROM public.promo;
DELETE
FROM public.products;
DELETE
FROM public.buyers;
DELETE
FROM public.sellers;

-- Reset sequences
ALTER SEQUENCE sellers_seller_id_seq RESTART WITH 1;
ALTER SEQUENCE buyers_buyer_id_seq RESTART WITH 1;
ALTER SEQUENCE products_product_id_seq RESTART WITH 1;
ALTER SEQUENCE promo_promo_id_seq RESTART WITH 1;

-- Insert sample sellers
INSERT INTO public.sellers (seller_name)
VALUES ('TechMaster Computer'),
       ('Component Pro Store');

-- Insert sample buyers
INSERT INTO public.buyers (buyer_name, phone_number, address_street, address_district, address_city, address_province,
                           postal_code)
VALUES ('Budi Santoso', '081234567890', 'Jl. Mawar No. 123', 'Kebayoran Baru', 'Jakarta Selatan', 'DKI Jakarta',
        '12150'),
       ('Dewi Sulistiani', '087811223344', 'Jl. Melati No. 45', 'Tegalsari', 'Surabaya', 'Jawa Timur', '60261'),
       ('Ahmad Rahman', '089922334455', 'Jl. Kencana No. 67', 'Lowokwaru', 'Malang', 'Jawa Timur', '65141');

-- Insert PC components as products
INSERT INTO public.products (product_name, weight_kg, price, qty)
VALUES ('AMD Ryzen 7 5800X Processor', 0.5, 4799000, 10),
       ('NVIDIA RTX 3070 Graphics Card', 1.2, 9999000, 5),
       ('Samsung 970 EVO Plus 1TB NVMe SSD', 0.3, 1899000, 15),
       ('Corsair Vengeance 32GB DDR4 RAM', 0.2, 1499000, 20),
       ('ASUS ROG STRIX B550-F Motherboard', 2.0, 2899000, 8),
       ('Corsair RM750x Power Supply', 1.8, 1799000, 12),
       ('NZXT H510 Case', 6.5, 1299000, 6);

-- Insert promotional offers
INSERT INTO public.promo (name, start_date, end_date, amount, promo_type, deduction_type)
VALUES ('Year End Sale', '2024-10-01', '2024-12-31', 500000, 1, 1), -- Fixed amount discount
       ('New User Discount', '2024-10-01', '2024-12-31', 10, 1, 2);
-- Percentage discount

-- Insert sample invoices and items

-- Invoice 1: Single item purchase without promo
INSERT INTO public.invoices (invoice_id, seller_id, buyer_id, purchase_date, shipping_cost,
                             shipping_insurance, service_fee, application_fee, shipping_method, payment_method)
VALUES ('INV-2024100101', 1, 1, '2024-10-01', 50000,
        25000, 15000, 10000, 'JNE Regular', 'Bank Transfer');

INSERT INTO public.invoice_items (invoice_id, product_id, quantity, unit_price, subtotal)
SELECT 'INV-2024100101', product_id, 1, price, price
FROM products
WHERE product_name = 'AMD Ryzen 7 5800X Processor';

-- Invoice 2: Multiple items purchase with promo
INSERT INTO public.invoices (invoice_id, seller_id, buyer_id, purchase_date, shipping_cost,
                             shipping_insurance, service_fee, application_fee, shipping_method, payment_method)
VALUES ('INV-2024100102', 2, 2, '2024-10-01', 150000,
        75000, 25000, 20000, 'JNE YES', 'Credit Card');

-- Insert multiple items for Invoice 2
INSERT INTO public.invoice_items (invoice_id, product_id, quantity, unit_price, subtotal)
SELECT 'INV-2024100102',
       product_id,
       CASE
           WHEN product_name = 'Samsung 970 EVO Plus 1TB NVMe SSD' THEN 2
           ELSE 1
           END,
       price,
       CASE
           WHEN product_name = 'Samsung 970 EVO Plus 1TB NVMe SSD' THEN price * 2
           ELSE price
           END
FROM products
WHERE product_name IN (
                       'NVIDIA RTX 3070 Graphics Card',
                       'Samsung 970 EVO Plus 1TB NVMe SSD',
                       'Corsair Vengeance 32GB DDR4 RAM'
    );

INSERT INTO public.promo_usage (promo_id, invoice_id)
SELECT promo_id, 'INV-2024100102'
FROM promo
WHERE name = 'Year End Sale';

-- Invoice 3: Full PC build with new user promo
INSERT INTO public.invoices (invoice_id, seller_id, buyer_id, purchase_date, shipping_cost,
                             shipping_insurance, service_fee, application_fee, shipping_method, payment_method)
VALUES ('INV-2024100103', 1, 3, '2024-10-01', 200000,
        100000, 30000, 25000, 'SiCepat Express', 'Bank Transfer');

-- Insert all components for full build
INSERT INTO public.invoice_items (invoice_id, product_id, quantity, unit_price, subtotal)
SELECT 'INV-2024100103', product_id, 1, price, price
FROM products;

INSERT INTO public.promo_usage (promo_id, invoice_id)
SELECT promo_id, 'INV-2024100103'
FROM promo
WHERE name = 'New User Discount';

