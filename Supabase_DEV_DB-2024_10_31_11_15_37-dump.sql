--
-- PostgreSQL database dump
--

-- Dumped from database version 15.6
-- Dumped by pg_dump version 17.0

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.promo_usage DROP CONSTRAINT IF EXISTS promo_usage_promo_id_fkey;
ALTER TABLE IF EXISTS ONLY public.promo_usage DROP CONSTRAINT IF EXISTS promo_usage_invoice_id_fkey;
ALTER TABLE IF EXISTS ONLY public.invoice_items DROP CONSTRAINT IF EXISTS invoice_items_product_id_fkey;
ALTER TABLE IF EXISTS ONLY public.invoice_items DROP CONSTRAINT IF EXISTS invoice_items_invoice_id_fkey;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS fk_invoice_seller;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS fk_invoice_buyer;
DROP TRIGGER IF EXISTS sellers_versioning_trigger ON public.sellers;
DROP TRIGGER IF EXISTS products_versioning_trigger ON public.products;
DROP TRIGGER IF EXISTS buyers_versioning_trigger ON public.buyers;
DROP INDEX IF EXISTS public.idx_sellers_history_period;
DROP INDEX IF EXISTS public.idx_products_history_period;
DROP INDEX IF EXISTS public.idx_buyers_history_period;
ALTER TABLE IF EXISTS ONLY public.sellers DROP CONSTRAINT IF EXISTS sellers_pkey;
ALTER TABLE IF EXISTS ONLY public.promo DROP CONSTRAINT IF EXISTS promo_pkey;
ALTER TABLE IF EXISTS ONLY public.products DROP CONSTRAINT IF EXISTS products_pkey;
ALTER TABLE IF EXISTS ONLY public.invoices DROP CONSTRAINT IF EXISTS invoices_pkey;
ALTER TABLE IF EXISTS ONLY public.invoice_items DROP CONSTRAINT IF EXISTS invoice_items_pkey;
ALTER TABLE IF EXISTS ONLY public.buyers DROP CONSTRAINT IF EXISTS buyers_pkey;
ALTER TABLE IF EXISTS public.sellers ALTER COLUMN seller_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.promo ALTER COLUMN promo_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.products ALTER COLUMN product_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.invoice_items ALTER COLUMN invoice_item_id DROP DEFAULT;
ALTER TABLE IF EXISTS public.buyers ALTER COLUMN buyer_id DROP DEFAULT;
DROP SEQUENCE IF EXISTS public.sellers_seller_id_seq;
DROP TABLE IF EXISTS public.sellers_history;
DROP TABLE IF EXISTS public.sellers;
DROP TABLE IF EXISTS public.promo_usage;
DROP SEQUENCE IF EXISTS public.promo_promo_id_seq;
DROP TABLE IF EXISTS public.promo;
DROP SEQUENCE IF EXISTS public.products_product_id_seq;
DROP TABLE IF EXISTS public.products_history;
DROP TABLE IF EXISTS public.products;
DROP TABLE IF EXISTS public.invoices;
DROP SEQUENCE IF EXISTS public.invoice_items_invoice_item_id_seq;
DROP TABLE IF EXISTS public.invoice_items;
DROP TABLE IF EXISTS public.buyers_history;
DROP SEQUENCE IF EXISTS public.buyers_buyer_id_seq;
DROP TABLE IF EXISTS public.buyers;
DROP FUNCTION IF EXISTS public.versioning();
DROP FUNCTION IF EXISTS public.get_invoice_details(p_invoice_id character varying);
DROP SCHEMA IF EXISTS public;
--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: get_invoice_details(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_invoice_details(p_invoice_id character varying) RETURNS TABLE(invoice_id character varying, purchase_date date, buyer_name character varying, seller_name character varying, product_name character varying, quantity integer, unit_price numeric, subtotal numeric, historical_price numeric, price_difference numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
        SELECT
            i.invoice_id,
            i.purchase_date,
            b.buyer_name,
            COALESCE(sh.seller_name, s.seller_name) as seller_name,
            COALESCE(ph.product_name, p.product_name) as product_name,
            ii.quantity,
            ii.unit_price,
            ii.subtotal,
            COALESCE(ph.price, p.price) as historical_price,
            ii.unit_price - COALESCE(ph.price, p.price) as price_difference
        FROM
            public.invoices i
                JOIN public.buyers b ON i.buyer_id = b.buyer_id
                JOIN public.sellers s ON i.seller_id = s.seller_id
                LEFT JOIN public.sellers_history sh ON i.seller_id = sh.seller_id
                AND i.reference_time::timestamp with time zone <@ sh.system_period
                JOIN public.invoice_items ii ON i.invoice_id = ii.invoice_id
                JOIN public.products p ON ii.product_id = p.product_id
                LEFT JOIN public.products_history ph ON ii.product_id = ph.product_id
                AND i.reference_time::timestamp with time zone <@ ph.system_period
        WHERE
            i.invoice_id = p_invoice_id;
END;
$$;


ALTER FUNCTION public.get_invoice_details(p_invoice_id character varying) OWNER TO postgres;

--
-- Name: versioning(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.versioning() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
BEGIN
    -- If this is an update
    IF (TG_OP = 'UPDATE') THEN
        -- Insert the old version into history table
        EXECUTE format('INSERT INTO %I SELECT $1.*', TG_TABLE_NAME || '_history')
            USING OLD;

        -- Update the period end time for the old record
        NEW.system_period = tstzrange(CURRENT_TIMESTAMP, NULL);
        RETURN NEW;
        -- If this is a delete
    ELSIF (TG_OP = 'DELETE') THEN
        -- Insert the old version into history table
        EXECUTE format('INSERT INTO %I SELECT $1.*', TG_TABLE_NAME || '_history')
            USING OLD;
        RETURN OLD;
    END IF;
END;
$_$;


ALTER FUNCTION public.versioning() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: buyers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buyers (
    buyer_id integer NOT NULL,
    buyer_name character varying(100) NOT NULL,
    phone_number character varying(20),
    address_street character varying(200),
    address_district character varying(100),
    address_city character varying(100),
    address_province character varying(100),
    postal_code character varying(10),
    system_period tstzrange DEFAULT tstzrange(CURRENT_TIMESTAMP, NULL::timestamp with time zone) NOT NULL
);


ALTER TABLE public.buyers OWNER TO postgres;

--
-- Name: buyers_buyer_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.buyers_buyer_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.buyers_buyer_id_seq OWNER TO postgres;

--
-- Name: buyers_buyer_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.buyers_buyer_id_seq OWNED BY public.buyers.buyer_id;


--
-- Name: buyers_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buyers_history (
    buyer_id integer,
    buyer_name character varying(100) NOT NULL,
    phone_number character varying(20),
    address_street character varying(200),
    address_district character varying(100),
    address_city character varying(100),
    address_province character varying(100),
    postal_code character varying(10),
    system_period tstzrange NOT NULL
);


ALTER TABLE public.buyers_history OWNER TO postgres;

--
-- Name: invoice_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoice_items (
    invoice_item_id integer NOT NULL,
    invoice_id character varying(50),
    product_id integer NOT NULL,
    quantity integer NOT NULL,
    unit_price numeric(15,2) NOT NULL,
    subtotal numeric(15,2) NOT NULL
);


ALTER TABLE public.invoice_items OWNER TO postgres;

--
-- Name: invoice_items_invoice_item_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.invoice_items_invoice_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.invoice_items_invoice_item_id_seq OWNER TO postgres;

--
-- Name: invoice_items_invoice_item_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.invoice_items_invoice_item_id_seq OWNED BY public.invoice_items.invoice_item_id;


--
-- Name: invoices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invoices (
    invoice_id character varying(50) NOT NULL,
    seller_id integer NOT NULL,
    buyer_id integer NOT NULL,
    purchase_date date NOT NULL,
    reference_time timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    shipping_cost numeric(15,2) NOT NULL,
    shipping_insurance numeric(15,2) NOT NULL,
    service_fee numeric(15,2) NOT NULL,
    application_fee numeric(15,2) NOT NULL,
    shipping_method character varying(50) NOT NULL,
    payment_method character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


ALTER TABLE public.invoices OWNER TO postgres;

--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    product_id integer NOT NULL,
    product_name character varying(200) NOT NULL,
    weight_kg numeric(10,2),
    price numeric(15,2) NOT NULL,
    system_period tstzrange DEFAULT tstzrange(CURRENT_TIMESTAMP, NULL::timestamp with time zone) NOT NULL,
    qty integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products_history (
    product_id integer,
    product_name character varying(200) NOT NULL,
    weight_kg numeric(10,2),
    price numeric(15,2) NOT NULL,
    system_period tstzrange NOT NULL,
    qty integer DEFAULT 1 NOT NULL
);


ALTER TABLE public.products_history OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_product_id_seq OWNER TO postgres;

--
-- Name: products_product_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_product_id_seq OWNED BY public.products.product_id;


--
-- Name: promo; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.promo (
    promo_id integer NOT NULL,
    name character varying(100) NOT NULL,
    start_date timestamp with time zone NOT NULL,
    end_date timestamp with time zone NOT NULL,
    amount numeric NOT NULL,
    promo_type integer DEFAULT 1 NOT NULL,
    deduction_type integer DEFAULT 1 NOT NULL,
    system_period tstzrange DEFAULT tstzrange(CURRENT_TIMESTAMP, NULL::timestamp with time zone) NOT NULL
);


ALTER TABLE public.promo OWNER TO postgres;

--
-- Name: promo_promo_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.promo_promo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.promo_promo_id_seq OWNER TO postgres;

--
-- Name: promo_promo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.promo_promo_id_seq OWNED BY public.promo.promo_id;


--
-- Name: promo_usage; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.promo_usage (
    promo_id integer NOT NULL,
    invoice_id character varying(50) NOT NULL
);


ALTER TABLE public.promo_usage OWNER TO postgres;

--
-- Name: sellers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sellers (
    seller_id integer NOT NULL,
    seller_name character varying(100) NOT NULL,
    system_period tstzrange DEFAULT tstzrange(CURRENT_TIMESTAMP, NULL::timestamp with time zone) NOT NULL
);


ALTER TABLE public.sellers OWNER TO postgres;

--
-- Name: sellers_history; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.sellers_history (
    seller_id integer,
    seller_name character varying(100) NOT NULL,
    system_period tstzrange NOT NULL
);


ALTER TABLE public.sellers_history OWNER TO postgres;

--
-- Name: sellers_seller_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.sellers_seller_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.sellers_seller_id_seq OWNER TO postgres;

--
-- Name: sellers_seller_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.sellers_seller_id_seq OWNED BY public.sellers.seller_id;


--
-- Name: buyers buyer_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buyers ALTER COLUMN buyer_id SET DEFAULT nextval('public.buyers_buyer_id_seq'::regclass);


--
-- Name: invoice_items invoice_item_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items ALTER COLUMN invoice_item_id SET DEFAULT nextval('public.invoice_items_invoice_item_id_seq'::regclass);


--
-- Name: products product_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products ALTER COLUMN product_id SET DEFAULT nextval('public.products_product_id_seq'::regclass);


--
-- Name: promo promo_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promo ALTER COLUMN promo_id SET DEFAULT nextval('public.promo_promo_id_seq'::regclass);


--
-- Name: sellers seller_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sellers ALTER COLUMN seller_id SET DEFAULT nextval('public.sellers_seller_id_seq'::regclass);


--
-- Data for Name: buyers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buyers (buyer_id, buyer_name, phone_number, address_street, address_district, address_city, address_province, postal_code, system_period) FROM stdin;
1	Budi Santoso	081234567890	Jl. Mawar No. 123	Kebayoran Baru	Jakarta Selatan	DKI Jakarta	12150	["2024-10-31 02:41:36.409862+00",)
2	Dewi Sulistiani	087811223344	Jl. Melati No. 45	Tegalsari	Surabaya	Jawa Timur	60261	["2024-10-31 02:41:36.409862+00",)
3	Ahmad Rahman	089922334455	Jl. Kencana No. 67	Lowokwaru	Malang	Jawa Timur	65141	["2024-10-31 02:41:36.409862+00",)
\.


--
-- Data for Name: buyers_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.buyers_history (buyer_id, buyer_name, phone_number, address_street, address_district, address_city, address_province, postal_code, system_period) FROM stdin;
\.


--
-- Data for Name: invoice_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoice_items (invoice_item_id, invoice_id, product_id, quantity, unit_price, subtotal) FROM stdin;
1	INV-2024100101	1	1	4799000.00	4799000.00
2	INV-2024100102	2	1	9999000.00	9999000.00
3	INV-2024100102	3	2	1899000.00	3798000.00
4	INV-2024100102	4	1	1499000.00	1499000.00
5	INV-2024100103	1	1	4799000.00	4799000.00
6	INV-2024100103	2	1	9999000.00	9999000.00
7	INV-2024100103	3	1	1899000.00	1899000.00
8	INV-2024100103	4	1	1499000.00	1499000.00
9	INV-2024100103	5	1	2899000.00	2899000.00
10	INV-2024100103	6	1	1799000.00	1799000.00
11	INV-2024100103	7	1	1299000.00	1299000.00
\.


--
-- Data for Name: invoices; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invoices (invoice_id, seller_id, buyer_id, purchase_date, reference_time, shipping_cost, shipping_insurance, service_fee, application_fee, shipping_method, payment_method, created_at) FROM stdin;
INV-2024100101	1	1	2024-10-01	2024-10-31 02:41:50.044846	50000.00	25000.00	15000.00	10000.00	JNE Regular	Bank Transfer	2024-10-31 02:41:50.044846
INV-2024100102	2	2	2024-10-01	2024-10-31 02:42:03.147204	150000.00	75000.00	25000.00	20000.00	JNE YES	Credit Card	2024-10-31 02:42:03.147204
INV-2024100103	1	3	2024-10-01	2024-10-31 02:42:18.316743	200000.00	100000.00	30000.00	25000.00	SiCepat Express	Bank Transfer	2024-10-31 02:42:18.316743
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (product_id, product_name, weight_kg, price, system_period, qty) FROM stdin;
2	NVIDIA RTX 3070 Graphics Card	1.20	9999000.00	["2024-10-31 02:41:41.066589+00",)	5
3	Samsung 970 EVO Plus 1TB NVMe SSD	0.30	1899000.00	["2024-10-31 02:41:41.066589+00",)	15
4	Corsair Vengeance 32GB DDR4 RAM	0.20	1499000.00	["2024-10-31 02:41:41.066589+00",)	20
5	ASUS ROG STRIX B550-F Motherboard	2.00	2899000.00	["2024-10-31 02:41:41.066589+00",)	8
6	Corsair RM750x Power Supply	1.80	1799000.00	["2024-10-31 02:41:41.066589+00",)	12
7	NZXT H510 Case	6.50	1299000.00	["2024-10-31 02:41:41.066589+00",)	6
1	AMD Ryzen 7 5800X Processor 3.8Ghz 105W AM4	0.50	4799000.00	["2024-10-31 03:21:52.355187+00",)	10
\.


--
-- Data for Name: products_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products_history (product_id, product_name, weight_kg, price, system_period, qty) FROM stdin;
1	AMD Ryzen 7 5800X Processor	0.50	4799000.00	["2024-10-31 02:41:41.066589+00",)	10
1	AMD Ryzen 7 5800X Processor 3.8Ghz	0.50	4799000.00	["2024-10-31 03:13:22.613436+00",)	10
\.


--
-- Data for Name: promo; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.promo (promo_id, name, start_date, end_date, amount, promo_type, deduction_type, system_period) FROM stdin;
1	Year End Sale	2024-10-01 00:00:00+00	2024-12-31 00:00:00+00	500000	1	1	["2024-10-31 02:41:45.908299+00",)
2	New User Discount	2024-10-01 00:00:00+00	2024-12-31 00:00:00+00	10	1	2	["2024-10-31 02:41:45.908299+00",)
\.


--
-- Data for Name: promo_usage; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.promo_usage (promo_id, invoice_id) FROM stdin;
1	INV-2024100102
2	INV-2024100103
\.


--
-- Data for Name: sellers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sellers (seller_id, seller_name, system_period) FROM stdin;
1	TechMaster Computer	["2024-10-31 02:41:31.879388+00",)
2	Component Pro Store	["2024-10-31 02:41:31.879388+00",)
\.


--
-- Data for Name: sellers_history; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.sellers_history (seller_id, seller_name, system_period) FROM stdin;
\.


--
-- Name: buyers_buyer_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.buyers_buyer_id_seq', 3, true);


--
-- Name: invoice_items_invoice_item_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invoice_items_invoice_item_id_seq', 11, true);


--
-- Name: products_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_product_id_seq', 7, true);


--
-- Name: promo_promo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.promo_promo_id_seq', 2, true);


--
-- Name: sellers_seller_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.sellers_seller_id_seq', 2, true);


--
-- Name: buyers buyers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.buyers
    ADD CONSTRAINT buyers_pkey PRIMARY KEY (buyer_id);


--
-- Name: invoice_items invoice_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_pkey PRIMARY KEY (invoice_item_id);


--
-- Name: invoices invoices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT invoices_pkey PRIMARY KEY (invoice_id);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (product_id);


--
-- Name: promo promo_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promo
    ADD CONSTRAINT promo_pkey PRIMARY KEY (promo_id);


--
-- Name: sellers sellers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.sellers
    ADD CONSTRAINT sellers_pkey PRIMARY KEY (seller_id);


--
-- Name: idx_buyers_history_period; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_buyers_history_period ON public.buyers_history USING gist (system_period);


--
-- Name: idx_products_history_period; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_history_period ON public.products_history USING gist (system_period);


--
-- Name: idx_sellers_history_period; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_sellers_history_period ON public.sellers_history USING gist (system_period);


--
-- Name: buyers buyers_versioning_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER buyers_versioning_trigger BEFORE DELETE OR UPDATE ON public.buyers FOR EACH ROW EXECUTE FUNCTION public.versioning();


--
-- Name: products products_versioning_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER products_versioning_trigger BEFORE DELETE OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.versioning();


--
-- Name: sellers sellers_versioning_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER sellers_versioning_trigger BEFORE DELETE OR UPDATE ON public.sellers FOR EACH ROW EXECUTE FUNCTION public.versioning();


--
-- Name: invoices fk_invoice_buyer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_invoice_buyer FOREIGN KEY (buyer_id) REFERENCES public.buyers(buyer_id);


--
-- Name: invoices fk_invoice_seller; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoices
    ADD CONSTRAINT fk_invoice_seller FOREIGN KEY (seller_id) REFERENCES public.sellers(seller_id);


--
-- Name: invoice_items invoice_items_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(invoice_id) ON DELETE CASCADE;


--
-- Name: invoice_items invoice_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invoice_items
    ADD CONSTRAINT invoice_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(product_id) ON DELETE CASCADE;


--
-- Name: promo_usage promo_usage_invoice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promo_usage
    ADD CONSTRAINT promo_usage_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES public.invoices(invoice_id) ON DELETE CASCADE;


--
-- Name: promo_usage promo_usage_promo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.promo_usage
    ADD CONSTRAINT promo_usage_promo_id_fkey FOREIGN KEY (promo_id) REFERENCES public.promo(promo_id) ON DELETE CASCADE;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION get_invoice_details(p_invoice_id character varying); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_invoice_details(p_invoice_id character varying) TO anon;
GRANT ALL ON FUNCTION public.get_invoice_details(p_invoice_id character varying) TO authenticated;
GRANT ALL ON FUNCTION public.get_invoice_details(p_invoice_id character varying) TO service_role;


--
-- Name: FUNCTION versioning(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.versioning() TO anon;
GRANT ALL ON FUNCTION public.versioning() TO authenticated;
GRANT ALL ON FUNCTION public.versioning() TO service_role;


--
-- Name: TABLE buyers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.buyers TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.buyers TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.buyers TO service_role;


--
-- Name: SEQUENCE buyers_buyer_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.buyers_buyer_id_seq TO anon;
GRANT ALL ON SEQUENCE public.buyers_buyer_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.buyers_buyer_id_seq TO service_role;


--
-- Name: TABLE buyers_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.buyers_history TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.buyers_history TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.buyers_history TO service_role;


--
-- Name: TABLE invoice_items; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.invoice_items TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.invoice_items TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.invoice_items TO service_role;


--
-- Name: SEQUENCE invoice_items_invoice_item_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.invoice_items_invoice_item_id_seq TO anon;
GRANT ALL ON SEQUENCE public.invoice_items_invoice_item_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.invoice_items_invoice_item_id_seq TO service_role;


--
-- Name: TABLE invoices; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.invoices TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.invoices TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.invoices TO service_role;


--
-- Name: TABLE products; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.products TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.products TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.products TO service_role;


--
-- Name: TABLE products_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.products_history TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.products_history TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.products_history TO service_role;


--
-- Name: SEQUENCE products_product_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.products_product_id_seq TO anon;
GRANT ALL ON SEQUENCE public.products_product_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.products_product_id_seq TO service_role;


--
-- Name: TABLE promo; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.promo TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.promo TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.promo TO service_role;


--
-- Name: SEQUENCE promo_promo_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.promo_promo_id_seq TO anon;
GRANT ALL ON SEQUENCE public.promo_promo_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.promo_promo_id_seq TO service_role;


--
-- Name: TABLE promo_usage; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.promo_usage TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.promo_usage TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.promo_usage TO service_role;


--
-- Name: TABLE sellers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.sellers TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.sellers TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.sellers TO service_role;


--
-- Name: TABLE sellers_history; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.sellers_history TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.sellers_history TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.sellers_history TO service_role;


--
-- Name: SEQUENCE sellers_seller_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.sellers_seller_id_seq TO anon;
GRANT ALL ON SEQUENCE public.sellers_seller_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.sellers_seller_id_seq TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

