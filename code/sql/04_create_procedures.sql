-- ============================================================
-- 仓库管理系统数据库 - 存储过程创建脚本
-- MySQL 8.0 / 依赖 01_create_tables.sql（需先建表）
-- 说明：
--   共 4 个存储过程，全部内置事务、SQLEXCEPTION 异常捕获、回滚，
--   统一使用 OUT 参数 p_status_code(0成功/1失败) 与 p_status_msg 返回结果。
--
--   与触发器的分工（避免双重累加/扣减）：
--     - 入库库存累加：由触发器 trg_inbound_item_after_insert 自动完成；
--     - 出库库存扣减：由触发器 trg_outbound_order_after_approve 在审核通过时完成；
--     - 存储过程负责单据、成本批次(stock_batch)、FIFO/LIFO 成本核算；
--     - 盘点/调拨无对应触发器，由存储过程显式修正/转移库存。
--
--   [①] sp_inbound         货品入库（新增入库单+明细+成本批次）
--   [②] sp_outbound_cost   出库成本核算（FIFO/LIFO）
--   [③] sp_stocktake       库存盘点（盘盈/盘亏修正库存 + 盘点记录）
--   [④] sp_transfer        批量货品调拨（跨仓库转移，JSON 明细）
--
-- 执行方式：mysql -u root -p < 04_create_procedures.sql
-- ============================================================

USE warehouse_db;

-- ------------------------------------------------------------
-- 删除旧存储过程（支持重复执行）
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_inbound;
DROP PROCEDURE IF EXISTS sp_outbound_cost;
DROP PROCEDURE IF EXISTS sp_stocktake;
DROP PROCEDURE IF EXISTS sp_transfer;

DELIMITER $$

-- ============================================================
-- 【① 货品入库存储过程 sp_inbound】
-- 业务流程：
--   1) 校验入库数量>0，生成入库单号；
--   2) 新增入库单主记录(status=1 已审核)；
--   3) 写入入库明细（触发器自动累加 stock）；
--   4) 写入成本批次 stock_batch（供 FIFO/LIFO 出库核算）；
--   5) 提交事务，异常时整体回滚。
-- 参数说明：
--   IN  p_warehouse_id 入库仓库编号
--   IN  p_goods_id     货品编号
--   IN  p_quantity     入库数量(>0)
--   IN  p_unit_price   入库单价
--   IN  p_operator_id  操作人编号
--   IN  p_supplier_id  供应商编号(可NULL)
--   IN  p_biz_type     业务类型(默认 PURCHASE)
--   OUT p_status_code  0成功 / 1失败
--   OUT p_status_msg   返回消息
-- ============================================================
CREATE PROCEDURE sp_inbound(
    IN  p_warehouse_id INT UNSIGNED,
    IN  p_goods_id     INT UNSIGNED,
    IN  p_quantity     DECIMAL(12,2),
    IN  p_unit_price   DECIMAL(12,2),
    IN  p_operator_id  INT UNSIGNED,
    IN  p_supplier_id  INT UNSIGNED,
    IN  p_biz_type     VARCHAR(20),
    OUT p_status_code  INT,
    OUT p_status_msg   VARCHAR(255)
)
BEGIN
    DECLARE v_inbound_id INT UNSIGNED;
    DECLARE v_item_id    INT UNSIGNED;
    DECLARE v_order_no   VARCHAR(50);
    DECLARE v_amount     DECIMAL(12,2);

    -- 异常处理器：任何 SQL 异常 -> 回滚并返回失败
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 p_status_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_status_code = 1;
    END;

    START TRANSACTION;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '入库数量必须大于0';
    END IF;

    SET v_amount   = p_quantity * p_unit_price;
    SET v_order_no = CONCAT('IN', DATE_FORMAT(NOW(6), '%Y%m%d%H%i%s%f'));

    -- 1. 新增入库单主记录（status=1 已审核，入库即生效）
    INSERT INTO inbound_order (order_no, biz_type, warehouse_id, supplier_id, operator_id, total_amount, status)
    VALUES (v_order_no, p_biz_type, p_warehouse_id, p_supplier_id, p_operator_id, v_amount, 1);
    SET v_inbound_id = LAST_INSERT_ID();

    -- 2. 写入入库明细（触发器 trg_inbound_item_after_insert 自动累加库存）
    INSERT INTO inbound_item (inbound_id, goods_id, quantity, unit_price, amount)
    VALUES (v_inbound_id, p_goods_id, p_quantity, p_unit_price, v_amount);
    SET v_item_id = LAST_INSERT_ID();

    -- 3. 写入成本批次（供 FIFO/LIFO 出库成本核算使用）
    INSERT INTO stock_batch (warehouse_id, goods_id, inbound_item_id, batch_no, quantity, unit_cost, inbound_date)
    VALUES (p_warehouse_id, p_goods_id, v_item_id, v_order_no, p_quantity, p_unit_price, CURDATE());

    COMMIT;
    SET p_status_code = 0;
    SET p_status_msg  = CONCAT('入库成功，入库单号：', v_order_no);
END$$

-- ============================================================
-- 【② 出库成本核算存储过程 sp_outbound_cost】
-- 业务流程：
--   1) 读取货品计价方式(FIFO/LIFO)；
--   2) 校验库存充足，按计价方式游标遍历成本批次；
--   3) FIFO 按入库日期升序扣减，LIFO 按降序扣减，累加出库成本；
--   4) 更新各批次剩余数量，生成出库单主表/明细(含单位成本)；
--   5) 审核通过（触发器自动扣减 stock），事务异常整体回滚。
-- 参数说明：
--   IN  p_warehouse_id  出库仓库编号
--   IN  p_goods_id      货品编号
--   IN  p_quantity      出库数量(>0)
--   IN  p_operator_id   操作人编号
--   IN  p_biz_type      业务类型(默认 SALE)
--   OUT p_status_code   0成功 / 1失败
--   OUT p_status_msg    返回消息
--   OUT p_out_total_cost 本次出库核算总成本
-- ============================================================
CREATE PROCEDURE sp_outbound_cost(
    IN  p_warehouse_id  INT UNSIGNED,
    IN  p_goods_id      INT UNSIGNED,
    IN  p_quantity      DECIMAL(12,2),
    IN  p_operator_id   INT UNSIGNED,
    IN  p_biz_type      VARCHAR(20),
    OUT p_status_code   INT,
    OUT p_status_msg    VARCHAR(255),
    OUT p_out_total_cost DECIMAL(12,2)
)
BEGIN
    DECLARE v_cost_method VARCHAR(10);
    DECLARE v_available   DECIMAL(12,2);
    DECLARE v_order_no    VARCHAR(50);
    DECLARE v_outbound_id INT UNSIGNED;
    DECLARE v_remain      DECIMAL(12,2);
    DECLARE v_batch_id    INT UNSIGNED;
    DECLARE v_batch_qty   DECIMAL(12,2);
    DECLARE v_batch_cost  DECIMAL(12,2);
    DECLARE v_use_qty     DECIMAL(12,2);
    DECLARE v_total_cost  DECIMAL(12,2) DEFAULT 0;
    DECLARE v_unit_cost   DECIMAL(12,2);
    DECLARE v_is_lifo     TINYINT DEFAULT 0;
    DECLARE done INT DEFAULT 0;

    -- FIFO 游标：入库日期升序（先进先出）
    DECLARE cur_fifo CURSOR FOR
        SELECT batch_id, quantity, unit_cost
        FROM stock_batch
        WHERE warehouse_id = p_warehouse_id AND goods_id = p_goods_id AND quantity > 0
        ORDER BY inbound_date ASC, batch_id ASC;

    -- LIFO 游标：入库日期降序（后进先出）
    DECLARE cur_lifo CURSOR FOR
        SELECT batch_id, quantity, unit_cost
        FROM stock_batch
        WHERE warehouse_id = p_warehouse_id AND goods_id = p_goods_id AND quantity > 0
        ORDER BY inbound_date DESC, batch_id DESC;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 p_status_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_status_code = 1;
    END;

    START TRANSACTION;

    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '出库数量必须大于0';
    END IF;

    -- 读取计价方式
    SELECT cost_method INTO v_cost_method FROM goods WHERE goods_id = p_goods_id;
    IF v_cost_method = 'LIFO' THEN
        SET v_is_lifo = 1;
    END IF;

    -- 校验库存充足（按批次汇总）
    SELECT COALESCE(SUM(quantity), 0) INTO v_available
    FROM stock_batch
    WHERE warehouse_id = p_warehouse_id AND goods_id = p_goods_id AND quantity > 0;

    IF v_available < p_quantity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '库存不足，无法出库';
    END IF;

    SET v_remain     = p_quantity;
    SET v_total_cost = 0;

    -- 打开对应计价方式的批次游标
    IF v_is_lifo = 1 THEN
        OPEN cur_lifo;
    ELSE
        OPEN cur_fifo;
    END IF;

    read_loop: LOOP
        IF v_is_lifo = 1 THEN
            FETCH cur_lifo INTO v_batch_id, v_batch_qty, v_batch_cost;
        ELSE
            FETCH cur_fifo INTO v_batch_id, v_batch_qty, v_batch_cost;
        END IF;

        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        -- 本批次可扣数量（不超过剩余需求）
        IF v_batch_qty >= v_remain THEN
            SET v_use_qty = v_remain;
        ELSE
            SET v_use_qty = v_batch_qty;
        END IF;

        SET v_total_cost = v_total_cost + v_use_qty * v_batch_cost;
        SET v_remain     = v_remain - v_use_qty;

        -- 扣减批次剩余数量
        UPDATE stock_batch
        SET quantity = quantity - v_use_qty
        WHERE batch_id = v_batch_id;

        IF v_remain <= 0 THEN
            LEAVE read_loop;
        END IF;
    END LOOP;

    IF v_is_lifo = 1 THEN
        CLOSE cur_lifo;
    ELSE
        CLOSE cur_fifo;
    END IF;

    IF v_remain > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '成本批次不足，出库核算失败';
    END IF;

    SET v_unit_cost = v_total_cost / p_quantity;
    SET v_order_no  = CONCAT('OUT', DATE_FORMAT(NOW(6), '%Y%m%d%H%i%s%f'));

    -- 新增出库单主表（status=0 待审核）
    INSERT INTO outbound_order (order_no, biz_type, warehouse_id, operator_id, total_cost, total_amount, status)
    VALUES (v_order_no, p_biz_type, p_warehouse_id, p_operator_id, v_total_cost, 0, 0);
    SET v_outbound_id = LAST_INSERT_ID();

    -- 写入出库明细（unit_cost 为加权平均单位成本）
    INSERT INTO outbound_item (outbound_id, goods_id, quantity, unit_cost, total_cost)
    VALUES (v_outbound_id, p_goods_id, p_quantity, v_unit_cost, v_total_cost);

    -- 审核通过（触发器 trg_outbound_order_after_approve 自动扣减库存）
    UPDATE outbound_order SET status = 1 WHERE outbound_id = v_outbound_id;

    COMMIT;
    SET p_status_code = 0;
    SET p_status_msg  = CONCAT('出库成功，计价方式=', v_cost_method, '，出库成本=', v_total_cost);
    SET p_out_total_cost = v_total_cost;
END$$

-- ============================================================
-- 【③ 库存盘点存储过程 sp_stocktake】
-- 业务流程：
--   1) 读取账面库存数量与占用资金；
--   2) 计算差异(实盘-账面)，判定 GAIN(盘盈)/LOSS(盘亏)/NONE；
--   3) 生成盘点单主表 + 盘点明细（盘点记录表 stocktake_order/stocktake_item）；
--   4) 按平均成本修正 stock 数量与占用资金；
--   5) 事务异常整体回滚。
-- 参数说明：
--   IN  p_warehouse_id    盘点仓库编号
--   IN  p_goods_id        货品编号
--   IN  p_actual_quantity 实盘数量(>=0)
--   IN  p_operator_id     操作人编号
--   OUT p_status_code     0成功 / 1失败
--   OUT p_status_msg      返回消息
-- ============================================================
CREATE PROCEDURE sp_stocktake(
    IN  p_warehouse_id    INT UNSIGNED,
    IN  p_goods_id        INT UNSIGNED,
    IN  p_actual_quantity DECIMAL(12,2),
    IN  p_operator_id     INT UNSIGNED,
    OUT p_status_code     INT,
    OUT p_status_msg      VARCHAR(255)
)
BEGIN
    DECLARE v_book_qty    DECIMAL(12,2) DEFAULT 0;
    DECLARE v_total_cost  DECIMAL(12,2) DEFAULT 0;
    DECLARE v_avg_cost    DECIMAL(12,2) DEFAULT 0;
    DECLARE v_diff        DECIMAL(12,2);
    DECLARE v_diff_type   VARCHAR(10);
    DECLARE v_stocktake_id INT UNSIGNED;
    DECLARE v_order_no    VARCHAR(50);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 p_status_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_status_code = 1;
    END;

    START TRANSACTION;

    IF p_actual_quantity IS NULL OR p_actual_quantity < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '实盘数量不能为负';
    END IF;

    -- 读取账面库存
    SET v_book_qty   = COALESCE((SELECT quantity   FROM stock WHERE warehouse_id = p_warehouse_id AND goods_id = p_goods_id), 0);
    SET v_total_cost = COALESCE((SELECT total_cost FROM stock WHERE warehouse_id = p_warehouse_id AND goods_id = p_goods_id), 0);

    SET v_diff = p_actual_quantity - v_book_qty;
    IF v_diff > 0 THEN
        SET v_diff_type = 'GAIN';
    ELSEIF v_diff < 0 THEN
        SET v_diff_type = 'LOSS';
    ELSE
        SET v_diff_type = 'NONE';
    END IF;

    -- 计算平均单位成本（用于修正占用资金；无账面库存时用货品参考售价）
    IF v_book_qty > 0 THEN
        SET v_avg_cost = v_total_cost / v_book_qty;
    ELSE
        SET v_avg_cost = COALESCE((SELECT price FROM goods WHERE goods_id = p_goods_id), 0);
    END IF;

    -- 生成盘点单主表（盘点记录表）
    SET v_order_no = CONCAT('ST', DATE_FORMAT(NOW(6), '%Y%m%d%H%i%s%f'));
    INSERT INTO stocktake_order (order_no, warehouse_id, operator_id, status)
    VALUES (v_order_no, p_warehouse_id, p_operator_id, 1);
    SET v_stocktake_id = LAST_INSERT_ID();

    -- 生成盘点明细
    INSERT INTO stocktake_item (stocktake_id, goods_id, book_quantity, actual_quantity, diff_quantity, diff_type)
    VALUES (v_stocktake_id, p_goods_id, v_book_qty, p_actual_quantity, v_diff, v_diff_type);

    -- 修正库存数量与占用资金（无行则插入）
    INSERT INTO stock (warehouse_id, goods_id, quantity, total_cost)
    VALUES (p_warehouse_id, p_goods_id, p_actual_quantity, p_actual_quantity * v_avg_cost)
    ON DUPLICATE KEY UPDATE
        quantity   = p_actual_quantity,
        total_cost = p_actual_quantity * v_avg_cost;

    COMMIT;
    SET p_status_code = 0;
    SET p_status_msg  = CONCAT('盘点完成，差异类型=', v_diff_type, '，差异数量=', v_diff);
END$$

-- ============================================================
-- 【④ 批量货品调拨存储过程 sp_transfer】
-- 业务流程：
--   1) 校验调出/调入仓库不同；
--   2) 生成调拨单主表，遍历 JSON 明细[{goods_id, quantity}]；
--   3) 逐项校验源仓库库存，扣减源仓库数量与占用资金；
--   4) 增加目标仓库数量与占用资金，写入调拨明细；
--   5) 全部在同一事务，任一项失败整体回滚。
-- 参数说明：
--   IN  p_from_warehouse_id 调出仓库编号
--   IN  p_to_warehouse_id   调入仓库编号
--   IN  p_operator_id       操作人编号
--   IN  p_items             明细JSON，如 '[{"goods_id":1,"quantity":10}]'
--   OUT p_status_code       0成功 / 1失败
--   OUT p_status_msg        返回消息
-- ============================================================
CREATE PROCEDURE sp_transfer(
    IN  p_from_warehouse_id INT UNSIGNED,
    IN  p_to_warehouse_id   INT UNSIGNED,
    IN  p_operator_id       INT UNSIGNED,
    IN  p_items             JSON,
    OUT p_status_code       INT,
    OUT p_status_msg        VARCHAR(255)
)
BEGIN
    DECLARE v_transfer_id INT UNSIGNED;
    DECLARE v_order_no    VARCHAR(50);
    DECLARE v_goods_id    INT UNSIGNED;
    DECLARE v_quantity    DECIMAL(12,2);
    DECLARE v_available   DECIMAL(12,2);
    DECLARE v_avg_cost    DECIMAL(12,2);
    DECLARE done INT DEFAULT 0;

    -- 解析 JSON 明细为游标
    DECLARE cur CURSOR FOR
        SELECT jt.goods_id, jt.quantity
        FROM JSON_TABLE(p_items, '$[*]' COLUMNS(
            goods_id INT PATH '$.goods_id',
            quantity DECIMAL(12,2) PATH '$.quantity'
        )) AS jt;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 p_status_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_status_code = 1;
    END;

    START TRANSACTION;

    IF p_from_warehouse_id = p_to_warehouse_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '调出仓库与调入仓库不能相同';
    END IF;

    IF p_items IS NULL OR JSON_LENGTH(p_items) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '调拨明细不能为空';
    END IF;

    SET v_order_no = CONCAT('TR', DATE_FORMAT(NOW(6), '%Y%m%d%H%i%s%f'));

    -- 生成调拨单主表
    INSERT INTO transfer_order (order_no, from_warehouse_id, to_warehouse_id, operator_id, status)
    VALUES (v_order_no, p_from_warehouse_id, p_to_warehouse_id, p_operator_id, 1);
    SET v_transfer_id = LAST_INSERT_ID();

    OPEN cur;
    read_loop: LOOP
        FETCH cur INTO v_goods_id, v_quantity;
        IF done = 1 THEN
            LEAVE read_loop;
        END IF;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '调拨数量必须大于0';
        END IF;

        -- 校验源仓库库存
        SET v_available = COALESCE((SELECT quantity FROM stock WHERE warehouse_id = p_from_warehouse_id AND goods_id = v_goods_id), 0);
        IF v_available < v_quantity THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '源仓库库存不足，无法调拨';
        END IF;

        -- 源仓库平均成本
        SET v_avg_cost = COALESCE((SELECT total_cost / NULLIF(quantity, 0) FROM stock WHERE warehouse_id = p_from_warehouse_id AND goods_id = v_goods_id), 0);

        -- 扣减源仓库
        UPDATE stock
        SET quantity   = quantity - v_quantity,
            total_cost = total_cost - v_quantity * v_avg_cost
        WHERE warehouse_id = p_from_warehouse_id AND goods_id = v_goods_id;

        -- 增加目标仓库（无行则插入）
        INSERT INTO stock (warehouse_id, goods_id, quantity, total_cost)
        VALUES (p_to_warehouse_id, v_goods_id, v_quantity, v_quantity * v_avg_cost)
        ON DUPLICATE KEY UPDATE
            quantity   = quantity + v_quantity,
            total_cost = total_cost + v_quantity * v_avg_cost;

        -- 写入调拨明细
        INSERT INTO transfer_item (transfer_id, goods_id, quantity)
        VALUES (v_transfer_id, v_goods_id, v_quantity);
    END LOOP;
    CLOSE cur;

    COMMIT;
    SET p_status_code = 0;
    SET p_status_msg  = CONCAT('调拨成功，调拨单号：', v_order_no);
END$$

DELIMITER ;

-- ============================================================
-- CALL 调用示例（演示时逐条执行，先看结果再继续）
-- ============================================================
-- 前置：确保存在 warehouse_id=1、2，goods_id=1、2，operator_id=1

-- ① 入库：货品1入库100件@5元、再入库50件@6元（建立两个 FIFO 批次）
-- CALL sp_inbound(1, 1, 100, 5.00, 1, 1, 'PURCHASE', @c1, @m1);
-- SELECT @c1, @m1;
-- CALL sp_inbound(1, 1, 50, 6.00, 1, 1, 'PURCHASE', @c2, @m2);
-- SELECT @c2, @m2;

-- ② 出库成本核算：出库120件，FIFO 成本 = 100*5 + 20*6 = 620
-- CALL sp_outbound_cost(1, 1, 120, 1, 'SALE', @c3, @m3, @cost);
-- SELECT @c3, @m3, @cost;

-- ③ 库存盘点：货品1实盘 25 件（账面应为 30），盘亏 5 件
-- CALL sp_stocktake(1, 1, 25, 1, @c4, @m4);
-- SELECT @c4, @m4;

-- ④ 批量调拨：货品1调10件、货品2调5件，从仓库1到仓库2
-- CALL sp_transfer(1, 2, 1, '[{"goods_id":1,"quantity":10},{"goods_id":2,"quantity":5}]', @c5, @m5);
-- SELECT @c5, @m5;
