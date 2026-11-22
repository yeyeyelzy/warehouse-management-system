-- ============================================================
-- 仓库管理系统数据库 - 触发器创建脚本（完整版）
-- MySQL 8.0 / 依赖 01_create_tables.sql（需先建表）
-- 覆盖 CLAUDE.md 4.2 全部 4 项触发器需求，共 8 个触发器对象：
--   [① 入库累加]   trg_inbound_item_after_insert
--   [② 出库审核扣减] trg_outbound_order_after_approve
--   [③ 库存预警]   trg_stock_after_insert / trg_stock_after_update（新增）
--   [④ 删除修改回滚] trg_inbound_item_after_delete/update、
--                   trg_outbound_item_after_delete/update（新增）
-- 说明：
--   - 统一使用 AFTER 触发时机；
--   - 触发器仅做库存数量/占用资金/预警的机械联动，不实现 FIFO/LIFO
--     成本核算与 stock_batch 批次维护（由存储过程负责，避免重复）；
--   - 均含 DROP TRIGGER IF EXISTS，支持重复执行。
-- 执行方式：mysql -u root -p < 03_create_triggers.sql
-- ============================================================

USE warehouse_db;

-- ============================================================
-- 清理旧触发器（DROP IF EXISTS）
-- ============================================================
DROP TRIGGER IF EXISTS trg_inbound_item_after_insert;
DROP TRIGGER IF EXISTS trg_outbound_order_after_approve;
DROP TRIGGER IF EXISTS trg_stock_after_insert;
DROP TRIGGER IF EXISTS trg_stock_after_update;
DROP TRIGGER IF EXISTS trg_inbound_item_after_delete;
DROP TRIGGER IF EXISTS trg_inbound_item_after_update;
DROP TRIGGER IF EXISTS trg_outbound_item_after_delete;
DROP TRIGGER IF EXISTS trg_outbound_item_after_update;

DELIMITER $$

-- ------------------------------------------------------------
-- 【功能①】入库明细新增 -> 自动累加库存
-- 触发时机：AFTER INSERT ON inbound_item
-- 业务逻辑：从父表 inbound_order 获取仓库，按 warehouse_id+goods_id
--           累加 stock 数量与占用资金（无库存行则自动插入）。
-- ------------------------------------------------------------
CREATE TRIGGER trg_inbound_item_after_insert
AFTER INSERT ON inbound_item
FOR EACH ROW
BEGIN
    DECLARE v_warehouse_id INT UNSIGNED;

    -- 从入库单主表获取所属仓库
    SELECT warehouse_id INTO v_warehouse_id
    FROM inbound_order
    WHERE inbound_id = NEW.inbound_id;

    -- 累加库存：无则插入，有则累加数量与占用资金
    INSERT INTO stock (warehouse_id, goods_id, quantity, total_cost)
    VALUES (v_warehouse_id, NEW.goods_id, NEW.quantity, NEW.amount)
    ON DUPLICATE KEY UPDATE
        quantity   = quantity   + NEW.quantity,
        total_cost = total_cost + NEW.amount;
END$$

-- ------------------------------------------------------------
-- 【功能②】出库单审核通过 -> 自动扣减库存
-- 触发时机：AFTER UPDATE ON outbound_order
-- 业务逻辑：出库单状态由「非已审核」变更为「已审核(1)」时，
--           遍历该出库单全部明细，按仓库+货品扣减 stock 数量与占用资金。
-- ------------------------------------------------------------
CREATE TRIGGER trg_outbound_order_after_approve
AFTER UPDATE ON outbound_order
FOR EACH ROW
BEGIN
    DECLARE v_goods_id INT UNSIGNED;
    DECLARE v_quantity DECIMAL(12,2);
    DECLARE v_total_cost DECIMAL(12,2);
    DECLARE done INT DEFAULT 0;

    DECLARE cur CURSOR FOR
        SELECT goods_id, quantity, total_cost
        FROM outbound_item
        WHERE outbound_id = NEW.outbound_id;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

    -- 仅在状态由「非已审核」变更为「已审核」时触发一次扣减
    IF NEW.status = 1 AND OLD.status <> 1 THEN
        OPEN cur;
        read_loop: LOOP
            FETCH cur INTO v_goods_id, v_quantity, v_total_cost;
            IF done = 1 THEN
                LEAVE read_loop;
            END IF;
            UPDATE stock
            SET quantity   = quantity   - v_quantity,
                total_cost = total_cost - v_total_cost
            WHERE warehouse_id = NEW.warehouse_id
              AND goods_id     = v_goods_id;

            -- 当库存数量减到 0 时，强制将占用资金归零，避免盘点/调拨平均成本舍入误差残留
            UPDATE stock
            SET total_cost = 0
            WHERE warehouse_id = NEW.warehouse_id
              AND goods_id     = v_goods_id
              AND quantity <= 0;
        END LOOP;
        CLOSE cur;
    END IF;
END$$

-- ------------------------------------------------------------
-- 【功能③·新增】库存预警 - 库存新增后判断超储/短缺
-- 触发时机：AFTER INSERT ON stock
-- 业务逻辑：库存新增后，读取货品上下限阈值，若低于下限写入短缺(LOW)
--           预警，若高于上限写入超储(OVER)预警到 stock_alert。
-- ------------------------------------------------------------
CREATE TRIGGER trg_stock_after_insert
AFTER INSERT ON stock
FOR EACH ROW
BEGIN
    DECLARE v_lower DECIMAL(12,2);
    DECLARE v_upper DECIMAL(12,2);

    SELECT lower_limit, upper_limit INTO v_lower, v_upper
    FROM goods
    WHERE goods_id = NEW.goods_id;

    IF NEW.quantity < v_lower THEN
        INSERT INTO stock_alert (goods_id, warehouse_id, alert_type, current_quantity, threshold, alert_time, status)
        VALUES (NEW.goods_id, NEW.warehouse_id, 'LOW', NEW.quantity, v_lower, NOW(), 0);
    ELSEIF NEW.quantity > v_upper THEN
        INSERT INTO stock_alert (goods_id, warehouse_id, alert_type, current_quantity, threshold, alert_time, status)
        VALUES (NEW.goods_id, NEW.warehouse_id, 'OVER', NEW.quantity, v_upper, NOW(), 0);
    END IF;
END$$

-- ------------------------------------------------------------
-- 【功能③·新增】库存预警 - 库存数量变动后判断超储/短缺
-- 触发时机：AFTER UPDATE ON stock
-- 业务逻辑：仅当库存数量发生变化时判断，避免仅改占用资金时重复预警。
-- ------------------------------------------------------------
CREATE TRIGGER trg_stock_after_update
AFTER UPDATE ON stock
FOR EACH ROW
BEGIN
    DECLARE v_lower DECIMAL(12,2);
    DECLARE v_upper DECIMAL(12,2);

    IF NEW.quantity <> OLD.quantity THEN
        SELECT lower_limit, upper_limit INTO v_lower, v_upper
        FROM goods
        WHERE goods_id = NEW.goods_id;

        IF NEW.quantity < v_lower THEN
            INSERT INTO stock_alert (goods_id, warehouse_id, alert_type, current_quantity, threshold, alert_time, status)
            VALUES (NEW.goods_id, NEW.warehouse_id, 'LOW', NEW.quantity, v_lower, NOW(), 0);
        ELSEIF NEW.quantity > v_upper THEN
            INSERT INTO stock_alert (goods_id, warehouse_id, alert_type, current_quantity, threshold, alert_time, status)
            VALUES (NEW.goods_id, NEW.warehouse_id, 'OVER', NEW.quantity, v_upper, NOW(), 0);
        END IF;
    END IF;
END$$

-- ------------------------------------------------------------
-- 【功能④·新增】入库明细删除 -> 反向回滚库存
-- 触发时机：AFTER DELETE ON inbound_item
-- 业务逻辑：删除入库明细时，回减已累加的数量与占用资金。
-- ------------------------------------------------------------
CREATE TRIGGER trg_inbound_item_after_delete
AFTER DELETE ON inbound_item
FOR EACH ROW
BEGIN
    DECLARE v_warehouse_id INT UNSIGNED;

    SELECT warehouse_id INTO v_warehouse_id
    FROM inbound_order
    WHERE inbound_id = OLD.inbound_id;

    UPDATE stock
    SET quantity   = quantity   - OLD.quantity,
        total_cost = total_cost - OLD.amount
    WHERE warehouse_id = v_warehouse_id
      AND goods_id     = OLD.goods_id;
END$$

-- ------------------------------------------------------------
-- 【功能④·新增】入库明细修改数量 -> 反向回滚库存
-- 触发时机：AFTER UPDATE ON inbound_item
-- 业务逻辑：数量或金额变化时，按差值(新-旧)调整库存。
--           注：假设明细的 inbound_id/goods_id 不可修改，仅数量/金额可变。
-- ------------------------------------------------------------
CREATE TRIGGER trg_inbound_item_after_update
AFTER UPDATE ON inbound_item
FOR EACH ROW
BEGIN
    DECLARE v_warehouse_id INT UNSIGNED;

    IF NEW.quantity <> OLD.quantity OR NEW.amount <> OLD.amount THEN
        SELECT warehouse_id INTO v_warehouse_id
        FROM inbound_order
        WHERE inbound_id = NEW.inbound_id;

        UPDATE stock
        SET quantity   = quantity   + (NEW.quantity - OLD.quantity),
            total_cost = total_cost + (NEW.amount   - OLD.amount)
        WHERE warehouse_id = v_warehouse_id
          AND goods_id     = NEW.goods_id;
    END IF;
END$$

-- ------------------------------------------------------------
-- 【功能④·新增】出库明细删除 -> 反向回滚库存
-- 触发时机：AFTER DELETE ON outbound_item
-- 业务逻辑：仅当所属出库单已审核(status=1)时，回增已扣减的数量与成本。
-- ------------------------------------------------------------
CREATE TRIGGER trg_outbound_item_after_delete
AFTER DELETE ON outbound_item
FOR EACH ROW
BEGIN
    DECLARE v_warehouse_id INT UNSIGNED;
    DECLARE v_status TINYINT;

    SELECT warehouse_id, status INTO v_warehouse_id, v_status
    FROM outbound_order
    WHERE outbound_id = OLD.outbound_id;

    IF v_status = 1 THEN
        UPDATE stock
        SET quantity   = quantity   + OLD.quantity,
            total_cost = total_cost + OLD.total_cost
        WHERE warehouse_id = v_warehouse_id
          AND goods_id     = OLD.goods_id;
    END IF;
END$$

-- ------------------------------------------------------------
-- 【功能④·新增】出库明细修改数量 -> 反向回滚库存
-- 触发时机：AFTER UPDATE ON outbound_item
-- 业务逻辑：仅当所属出库单已审核(status=1)时，按差值(旧-新)调整库存。
--           注：假设明细的 outbound_id/goods_id 不可修改，仅数量/成本可变。
-- ------------------------------------------------------------
CREATE TRIGGER trg_outbound_item_after_update
AFTER UPDATE ON outbound_item
FOR EACH ROW
BEGIN
    DECLARE v_warehouse_id INT UNSIGNED;
    DECLARE v_status TINYINT;

    IF NEW.quantity <> OLD.quantity OR NEW.total_cost <> OLD.total_cost THEN
        SELECT warehouse_id, status INTO v_warehouse_id, v_status
        FROM outbound_order
        WHERE outbound_id = NEW.outbound_id;

        IF v_status = 1 THEN
            UPDATE stock
            SET quantity   = quantity   + (OLD.quantity   - NEW.quantity),
                total_cost = total_cost + (OLD.total_cost - NEW.total_cost)
            WHERE warehouse_id = v_warehouse_id
              AND goods_id     = NEW.goods_id;
        END IF;
    END IF;
END$$

DELIMITER ;
