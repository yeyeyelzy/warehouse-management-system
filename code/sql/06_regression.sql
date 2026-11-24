-- 在 05 重置之后执行，每轮从相同状态开始。任何断言失败都会引发 SQL 错误。
USE warehouse_db;
DROP PROCEDURE IF EXISTS assert_c_lab;
DELIMITER $$
CREATE PROCEDURE assert_c_lab(IN p_pass BOOLEAN, IN p_case VARCHAR(128))
BEGIN
    IF COALESCE(p_pass, FALSE) = FALSE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = p_case;
    END IF;
    SELECT p_case AS test_case, 'PASS' AS result;
END$$
DELIMITER ;

SELECT o.total_cost INTO @fifo FROM outbound_order o JOIN outbound_item i USING (outbound_id)
WHERE o.warehouse_id = 4 AND i.goods_id = 1;
SELECT o.total_cost INTO @lifo FROM outbound_order o JOIN outbound_item i USING (outbound_id)
WHERE o.warehouse_id = 4 AND i.goods_id = 2;
CALL assert_c_lab(@fifo = 620 AND @lifo = 650, 'C01: seed FIFO 620 and LIFO 650');

CALL sp_inbound(30, 29, 10, 10.00, 1, 1, 'PURCHASE', @code, @message);
CALL assert_c_lab(@code = 0, 'C02: first inbound accepted');
CALL sp_inbound(30, 29, 10, 20.00, 1, 1, 'PURCHASE', @code, @message);
CALL assert_c_lab(@code = 0 AND (SELECT quantity FROM stock WHERE warehouse_id = 30 AND goods_id = 29) = 20,
    'C03: second inbound and stock quantity');

CREATE TEMPORARY TABLE before_batch AS
SELECT batch_id, quantity, remaining_cost FROM stock_batch WHERE goods_id = 29 AND warehouse_id IN (29, 30);
CREATE TEMPORARY TABLE before_stock AS
SELECT warehouse_id, quantity, total_cost FROM stock WHERE goods_id = 29 AND warehouse_id IN (29, 30);
SET @before_stock_count = (SELECT COUNT(*) FROM before_stock);
SET @before_batch_count = (SELECT COUNT(*) FROM before_batch);
SET @out_headers = (SELECT COUNT(*) FROM outbound_order);
SET @out_items = (SELECT COUNT(*) FROM outbound_item);
SET @move_headers = (SELECT COUNT(*) FROM transfer_order);
SET @move_items = (SELECT COUNT(*) FROM transfer_item);
SET @count_headers = (SELECT COUNT(*) FROM stocktake_order);
SET @count_items = (SELECT COUNT(*) FROM stocktake_item);
SET @alerts = (SELECT COUNT(*) FROM stock_alert);

CALL sp_outbound_cost(30, 29, 21, 1, 'SALE', @code, @message, @cost);
CALL assert_c_lab(@code = 1 AND @cost IS NULL
    AND @out_headers = (SELECT COUNT(*) FROM outbound_order)
    AND @out_items = (SELECT COUNT(*) FROM outbound_item),
    'C04: insufficient outbound rejected without order');

CALL sp_stocktake(30, 29, -1, 1, @code, @message);
CALL assert_c_lab(@code = 1
    AND @count_headers = (SELECT COUNT(*) FROM stocktake_order)
    AND @count_items = (SELECT COUNT(*) FROM stocktake_item),
    'C05: negative count rejected without order');

CALL sp_transfer(30, 29, 1, '[{"goods_id":29,"quantity":5},{"goods_id":29,"quantity":16}]', @code, @message);
CALL assert_c_lab(@code = 1 AND @message LIKE '%库存不足%'
    AND @move_headers = (SELECT COUNT(*) FROM transfer_order)
    AND @move_items = (SELECT COUNT(*) FROM transfer_item),
    'C06: second transfer line rejected and order rolled back');

CALL assert_c_lab(
    @before_stock_count = (SELECT COUNT(*) FROM stock WHERE goods_id = 29 AND warehouse_id IN (29, 30))
    AND NOT EXISTS (SELECT 1 FROM before_stock b LEFT JOIN stock s ON s.goods_id = 29 AND s.warehouse_id = b.warehouse_id
                    WHERE NOT (s.quantity <=> b.quantity AND s.total_cost <=> b.total_cost))
    AND @before_batch_count =
        (SELECT COUNT(*) FROM stock_batch WHERE goods_id = 29 AND warehouse_id IN (29, 30))
    AND NOT EXISTS (SELECT 1 FROM before_batch b LEFT JOIN stock_batch s USING (batch_id)
                    WHERE NOT (s.quantity <=> b.quantity AND s.remaining_cost <=> b.remaining_cost))
    AND @alerts = (SELECT COUNT(*) FROM stock_alert),
    'C07: failed actions leave stock, batches and alerts unchanged');
DROP TEMPORARY TABLE before_batch, before_stock;

CALL sp_transfer(30, 29, 1, '[{"goods_id":29,"quantity":12}]', @code, @message);
CALL assert_c_lab(@code = 0
    AND (SELECT quantity FROM stock WHERE warehouse_id = 30 AND goods_id = 29) = 8
    AND (SELECT quantity FROM stock WHERE warehouse_id = 29 AND goods_id = 29) = 12,
    'C08: same quantity removed from source and added to destination');

CALL sp_outbound_cost(29, 29, 12, 1, 'SALE', @code, @message, @cost);
CALL assert_c_lab(@code = 0 AND @cost = 140
    AND (SELECT quantity FROM stock WHERE warehouse_id = 29 AND goods_id = 29) = 0,
    'C09: transferred FIFO stock can be sold at original batch costs');

CALL sp_stocktake(30, 29, 12, 1, @code, @message);
CALL assert_c_lab(@code = 0 AND EXISTS (
    SELECT 1 FROM stocktake_item i JOIN stocktake_order o USING (stocktake_id)
    WHERE o.warehouse_id = 30 AND i.goods_id = 29 AND i.diff_quantity = 4 AND i.diff_type = 'GAIN'),
    'C10: count gain recorded');
CALL sp_stocktake(30, 29, 2, 1, @code, @message);
CALL assert_c_lab(@code = 0 AND EXISTS (
    SELECT 1 FROM stocktake_item i JOIN stocktake_order o USING (stocktake_id)
    WHERE o.warehouse_id = 30 AND i.goods_id = 29 AND i.diff_quantity = -10 AND i.diff_type = 'LOSS')
    AND (SELECT SUM(quantity) FROM stock_batch WHERE warehouse_id = 30 AND goods_id = 29) = 2,
    'C11: count loss recorded and remaining batches match stock');

CALL assert_c_lab(EXISTS (
    SELECT 1 FROM v_stock_warning WHERE warehouse_name = '仓库30' AND goods_code = 'G029'
      AND warn_type = 'LOW' AND current_quantity = 2)
    AND EXISTS (SELECT 1 FROM stock_alert WHERE warehouse_id = 30 AND goods_id = 29
                AND alert_type = 'LOW' AND current_quantity = 2),
    'C12: low-stock alert and live view agree');

CALL sp_stocktake(30, 29, 1001, 1, @code, @message);
CALL assert_c_lab(@code = 0 AND EXISTS (
    SELECT 1 FROM v_stock_warning WHERE warehouse_name = '仓库30' AND goods_code = 'G029'
      AND warn_type = 'OVER' AND current_quantity = 1001)
    AND EXISTS (SELECT 1 FROM stock_alert WHERE warehouse_id = 30 AND goods_id = 29
                AND alert_type = 'OVER' AND current_quantity = 1001),
    'C13: overstock alert and live view agree');
SET @in_headers = (SELECT COUNT(*) FROM inbound_order);
SET @in_items = (SELECT COUNT(*) FROM inbound_item);
CALL sp_inbound(28, 25, 1, -1, 1, 1, 'PURCHASE', @code, @message);
CALL assert_c_lab(@code = 1 AND @message LIKE '%入库单价%'
    AND @in_headers = (SELECT COUNT(*) FROM inbound_order)
    AND @in_items = (SELECT COUNT(*) FROM inbound_item)
    AND NOT EXISTS (SELECT 1 FROM stock WHERE warehouse_id = 28 AND goods_id = 25)
    AND NOT EXISTS (SELECT 1 FROM stock_batch WHERE warehouse_id = 28 AND goods_id = 25),
    'C14: negative inbound price rejected without partial writes');

CALL sp_inbound(28, 26, 0.04, 0.50, 1, 1, 'PURCHASE', @code, @message);
CALL assert_c_lab(@code = 0, 'C15: fractional inbound accepted');
CALL sp_outbound_cost(28, 26, 0.01, 1, 'SALE', @code, @message, @cost);
SET @first_cost = IF(@code = 0, @cost, NULL);
CALL sp_outbound_cost(28, 26, 0.01, 1, 'SALE', @code, @message, @cost);
SET @second_cost = IF(@code = 0, @cost, NULL);
CALL sp_outbound_cost(28, 26, 0.01, 1, 'SALE', @code, @message, @cost);
CALL assert_c_lab(@code = 0 AND @first_cost + @second_cost + @cost = 0.02
    AND EXISTS (SELECT 1 FROM stock WHERE warehouse_id = 28 AND goods_id = 26 AND quantity = 0.01 AND total_cost = 0),
    'C16: three fractional outbounds keep cost nonnegative');
CALL sp_outbound_cost(28, 26, 0.01, 1, 'SALE', @code, @message, @cost);
CALL assert_c_lab(@code = 0 AND @cost = 0
    AND EXISTS (SELECT 1 FROM stock_batch
        WHERE warehouse_id = 28 AND goods_id = 26 AND quantity = 0 AND remaining_cost = 0),
    'C17: fully consumed fractional batch has zero residual cost');

CALL sp_inbound(28, 25, 0.04, 0.50, 1, 1, 'PURCHASE', @code, @message);
CALL sp_transfer(28, 27, 1, '[{"goods_id":25,"quantity":0.01}]', @code, @message);
CALL assert_c_lab(@code = 0
    AND (SELECT SUM(total_cost) FROM stock WHERE warehouse_id IN (27, 28) AND goods_id = 25) = 0.02
    AND EXISTS (SELECT 1 FROM stock_batch
        WHERE warehouse_id = 27 AND goods_id = 25 AND quantity = 0.01 AND remaining_cost = 0.01),
    'C18: fractional transfer conserves the source cost');
DROP PROCEDURE assert_c_lab;
