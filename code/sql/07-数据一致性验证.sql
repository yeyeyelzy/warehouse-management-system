-- 只读检查。每个检查结果应为 0 行。
USE warehouse_db;

SELECT 'negative_stock' AS check_name, warehouse_id, goods_id, quantity
FROM stock WHERE quantity < 0
UNION ALL
SELECT 'negative_batch', warehouse_id, goods_id, quantity
FROM stock_batch WHERE quantity < 0;

SELECT 'negative_stock_cost' AS check_name, warehouse_id, goods_id, total_cost
FROM stock WHERE total_cost < 0
UNION ALL
SELECT 'invalid_batch_cost', warehouse_id, goods_id, remaining_cost
FROM stock_batch WHERE remaining_cost < 0 OR (quantity = 0 AND remaining_cost <> 0);

SELECT 'invalid_inbound_price' AS check_name, inbound_id, item_id, unit_price
FROM inbound_item WHERE unit_price < 0;

WITH inventory_keys AS (
    SELECT warehouse_id, goods_id FROM stock
    UNION
    SELECT warehouse_id, goods_id FROM stock_batch
),
batches AS (
    SELECT warehouse_id, goods_id, SUM(quantity) AS quantity, SUM(remaining_cost) AS total_cost
    FROM stock_batch GROUP BY warehouse_id, goods_id
)
SELECT k.warehouse_id, k.goods_id, COALESCE(s.quantity, 0) AS stock_qty,
       COALESCE(b.quantity, 0) AS batch_qty,
       COALESCE(s.total_cost, 0) AS stock_cost, COALESCE(b.total_cost, 0) AS batch_cost
FROM inventory_keys k
LEFT JOIN stock s USING (warehouse_id, goods_id)
LEFT JOIN batches b USING (warehouse_id, goods_id)
WHERE COALESCE(s.quantity, 0) <> COALESCE(b.quantity, 0)
   OR COALESCE(s.total_cost, 0) <> COALESCE(b.total_cost, 0);

SELECT 'inbound_amount' AS check_name, o.inbound_id AS order_id, o.total_amount AS header_total,
       COALESCE(SUM(i.amount), 0) AS detail_total
FROM inbound_order o LEFT JOIN inbound_item i USING (inbound_id)
GROUP BY o.inbound_id, o.total_amount
HAVING header_total <> detail_total
UNION ALL
SELECT 'outbound_cost', o.outbound_id, o.total_cost, COALESCE(SUM(i.total_cost), 0)
FROM outbound_order o LEFT JOIN outbound_item i USING (outbound_id)
GROUP BY o.outbound_id, o.total_cost
HAVING o.total_cost <> COALESCE(SUM(i.total_cost), 0);

-- 出入库流水来自单据明细视图，校验每个方向的行数和数量。
WITH expected AS (
    SELECT 'IN' AS direction, COUNT(*) AS rows_expected, COALESCE(SUM(quantity), 0) AS quantity_expected
    FROM inbound_item
    UNION ALL
    SELECT 'OUT', COUNT(*), COALESCE(SUM(quantity), 0) FROM outbound_item
),
actual AS (
    SELECT flow_type, COUNT(*) AS rows_actual, SUM(quantity) AS quantity_actual
    FROM v_inout_summary GROUP BY flow_type
)
SELECT e.*, COALESCE(a.rows_actual, 0) AS rows_actual, COALESCE(a.quantity_actual, 0) AS quantity_actual
FROM expected e LEFT JOIN actual a ON a.flow_type = e.direction
WHERE e.rows_expected <> COALESCE(a.rows_actual, 0)
   OR e.quantity_expected <> COALESCE(a.quantity_actual, 0);

SELECT stocktake_id, goods_id, book_quantity, actual_quantity, diff_quantity, diff_type
FROM stocktake_item
WHERE actual_quantity < 0 OR diff_quantity <> actual_quantity - book_quantity
   OR diff_type <> CASE SIGN(actual_quantity - book_quantity)
                      WHEN 1 THEN 'GAIN' WHEN -1 THEN 'LOSS' ELSE 'NONE' END;

-- 历史预警对照事件发生时记录的数量和阈值。
SELECT alert_id, warehouse_id, goods_id, alert_type, current_quantity, threshold
FROM stock_alert
WHERE alert_type NOT IN ('LOW', 'OVER')
   OR (alert_type = 'LOW' AND current_quantity >= threshold)
   OR (alert_type = 'OVER' AND current_quantity <= threshold);
