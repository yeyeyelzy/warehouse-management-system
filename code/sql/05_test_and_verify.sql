-- ============================================================
-- 仓库管理系统数据库 - 测试数据 + 综合验证脚本
-- MySQL 8.0 / 依赖 01建表、02视图、03触发器、04存储过程
-- 数据指标：
--   - 每张基础实体表 >= 30 条（角色/用户/分类/供应商/仓库/货品）
--   - 入库/出库/盘点/调拨 明细关联记录合计 >= 200 条
-- 内容：
--   [0] 清理实验数据（TRUNCATE，支持反复调试）
--   [1] 批量插入基础数据（单表 >= 30 行）
--   [2] 批量采购入库单据（主表+明细+成本批次）
--   [3] 调用 4 个存储过程覆盖全部业务场景
--   [4] 验证查询：数据量、视图、统计 SQL、库存/盘点/预警
-- 执行方式：mysql -u root -p < 05_test_and_verify.sql
-- ============================================================

USE warehouse_db;

-- 关闭安全更新模式（避免 UPDATE/DELETE 无 KEY 条件时报 1175）
SET SQL_SAFE_UPDATES = 0;

-- ============================================================
-- [0] 清理实验数据（仅对可清空的 warehouse_db 执行）
-- ============================================================
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE stock_alert;
TRUNCATE TABLE stocktake_item;
TRUNCATE TABLE stocktake_order;
TRUNCATE TABLE transfer_item;
TRUNCATE TABLE transfer_order;
TRUNCATE TABLE outbound_item;
TRUNCATE TABLE outbound_order;
TRUNCATE TABLE stock_batch;
TRUNCATE TABLE inbound_item;
TRUNCATE TABLE inbound_order;
TRUNCATE TABLE stock;
TRUNCATE TABLE goods;
TRUNCATE TABLE warehouse;
TRUNCATE TABLE supplier;
TRUNCATE TABLE goods_category;
TRUNCATE TABLE sys_user;
TRUNCATE TABLE sys_role_permission;
TRUNCATE TABLE sys_permission;
TRUNCATE TABLE sys_role;
SET FOREIGN_KEY_CHECKS = 1;

-- 数字辅助表：用于批量生成 1..90
DROP TEMPORARY TABLE IF EXISTS nums;
CREATE TEMPORARY TABLE nums (n INT PRIMARY KEY);
INSERT INTO nums (n) VALUES
(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
(11),(12),(13),(14),(15),(16),(17),(18),(19),(20),
(21),(22),(23),(24),(25),(26),(27),(28),(29),(30),
(31),(32),(33),(34),(35),(36),(37),(38),(39),(40),
(41),(42),(43),(44),(45),(46),(47),(48),(49),(50),
(51),(52),(53),(54),(55),(56),(57),(58),(59),(60),
(61),(62),(63),(64),(65),(66),(67),(68),(69),(70),
(71),(72),(73),(74),(75),(76),(77),(78),(79),(80),
(81),(82),(83),(84),(85),(86),(87),(88),(89),(90);

-- ============================================================
-- [1] 批量插入基础数据（每表 30 行）
-- ============================================================

-- 角色表 30 行
INSERT INTO sys_role (role_id, role_name, role_code, description)
SELECT n, CONCAT('角色', n), CONCAT('ROLE_', LPAD(n,2,'0')), CONCAT('角色描述', n)
FROM nums WHERE n <= 30;

-- 用户表 30 行（角色循环 1~3）
INSERT INTO sys_user (user_id, username, password, real_name, role_id, status)
SELECT n, CONCAT('user', LPAD(n,2,'0')), '123456', CONCAT('用户', n), ((n-1)%3)+1, 1
FROM nums WHERE n <= 30;

-- 货品分类表 30 行
INSERT INTO goods_category (category_id, category_name, description)
SELECT n, CONCAT('分类', n), CONCAT('分类描述', n)
FROM nums WHERE n <= 30;

-- 供应商表 30 行
INSERT INTO supplier (supplier_id, supplier_name, contact_name, status)
SELECT n, CONCAT('供应商', n), CONCAT('联系人', n), 1
FROM nums WHERE n <= 30;

-- 仓库表 30 行
INSERT INTO warehouse (warehouse_id, warehouse_name, location)
SELECT n, CONCAT('仓库', n), CONCAT('位置', n)
FROM nums WHERE n <= 30;

-- 货品表 30 行（偶数编号 LIFO，奇数编号 FIFO）
INSERT INTO goods (goods_id, goods_code, goods_name, spec, unit, category_id, cost_method, upper_limit, lower_limit, price, status)
SELECT n, CONCAT('G', LPAD(n,3,'0')), CONCAT('货品', n), CONCAT('规格', n), '个',
       n, IF(n % 2 = 0, 'LIFO', 'FIFO'), 1000.00, 10.00, 10.00 + n, 1
FROM nums WHERE n <= 30;

-- ============================================================
-- [2] 批量采购入库单据（30 张主单 + 90 条明细 + 90 条成本批次）
--     明细 goods 循环 1~30，仓库循环 1~3，数量 10/20/30，单价 5/6/7
-- ============================================================

-- 入库单主表 30 行
INSERT INTO inbound_order (inbound_id, order_no, biz_type, warehouse_id, supplier_id, operator_id, inbound_date, status)
SELECT n, CONCAT('IN', LPAD(n,4,'0')), 'PURCHASE',
       ((n-1)%3)+1, ((n-1)%30)+1, ((n-1)%30)+1,
       DATE_SUB(NOW(), INTERVAL (60 - n) DAY), 1
FROM nums WHERE n <= 30;

-- 入库明细 90 行（触发器自动累加库存）
INSERT INTO inbound_item (item_id, inbound_id, goods_id, quantity, unit_price, amount)
SELECT n,
       FLOOR((n-1)/3)+1,
       ((n-1)%30)+1,
       10 * (((n-1)%3)+1),
       5.00 + ((n-1)%3),
       (10 * (((n-1)%3)+1)) * (5.00 + ((n-1)%3))
FROM nums WHERE n <= 90;

-- 成本批次 90 行（供 FIFO/LIFO 出库核算）
INSERT INTO stock_batch (batch_id, warehouse_id, goods_id, inbound_item_id, batch_no, quantity, unit_cost, remaining_cost, inbound_date)
SELECT n,
       ((FLOOR((n-1)/3))%3)+1,
       ((n-1)%30)+1,
       n,
       CONCAT('IN', LPAD(FLOOR((n-1)/3)+1, 4, '0')),
       10 * (((n-1)%3)+1),
       5.00 + ((n-1)%3),
       (10 * (((n-1)%3)+1)) * (5.00 + ((n-1)%3)),
       DATE(DATE_SUB(NOW(), INTERVAL (60 - (FLOOR((n-1)/3)+1)) DAY))
FROM nums WHERE n <= 90;

-- 回填入库单总金额（供供应商供货金额统计）
UPDATE inbound_order o
SET total_amount = (SELECT COALESCE(SUM(amount),0) FROM inbound_item i WHERE i.inbound_id = o.inbound_id)
WHERE o.inbound_id > 0;

-- ============================================================
-- [3] 调用 4 个存储过程，覆盖全部业务场景
-- ============================================================

-- 3.1 货品入库 sp_inbound（正常采购 / 销售退货 / 回料）
CALL sp_inbound(4, 1, 100, 5.00, 1, 1, 'PURCHASE',        @c, @m);   -- 正常采购入库
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_inbound(4, 1, 50,  6.00, 1, 1, 'PURCHASE',        @c, @m);   -- 第二批（FIFO 批次）
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_inbound(4, 2, 100, 5.00, 1, 1, 'PURCHASE',        @c, @m);   -- LIFO 货品第一批
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_inbound(4, 2, 50,  6.00, 1, 1, 'PURCHASE',        @c, @m);   -- LIFO 货品第二批
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_inbound(4, 3, 40,  4.00, 1, 1, 'SALE_RETURN',     @c, @m);   -- 销售退货入库
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_inbound(4, 4, 30,  3.00, 1, 1, 'MATERIAL_RETURN', @c, @m);   -- 回料入库
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;

-- 3.2 出库成本核算 sp_outbound_cost（FIFO / LIFO / 采购退货 / 领料）
CALL sp_outbound_cost(4, 1, 120, 1, 'SALE',            @c, @m, @cost); -- FIFO：100*5+20*6=620
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message, @cost AS cost;
CALL sp_outbound_cost(4, 2, 120, 1, 'SALE',            @c, @m, @cost); -- LIFO：50*6+70*5=650
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message, @cost AS cost;
CALL sp_outbound_cost(4, 3, 10,  1, 'PURCHASE_RETURN', @c, @m, @cost); -- 采购退货出库
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message, @cost AS cost;
CALL sp_outbound_cost(4, 4, 15,  1, 'MATERIAL_ISSUE',  @c, @m, @cost); -- 领料出库
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message, @cost AS cost;

-- 3.3 库存盘点 sp_stocktake（盘盈 / 盘亏 / 一般盘点）
CALL sp_stocktake(1, 5, 500, 1, @c, @m);   -- 盘盈（实际远大于账面）
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_stocktake(4, 4, 0,   1, @c, @m);   -- 盘亏（账面>0，实盘0）
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_stocktake(1, 7, 20,  1, @c, @m);   -- 一般盘点
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;

-- 3.4 批量调拨 sp_transfer（跨仓库，多货品 JSON）
CALL sp_transfer(4, 2, 1, '[{"goods_id":1,"quantity":10},{"goods_id":2,"quantity":5},{"goods_id":3,"quantity":8}]', @c, @m);
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;
CALL sp_transfer(1, 3, 1, '[{"goods_id":5,"quantity":6}]', @c, @m);
SELECT 'C_SEED_CALL', @c AS status_code, @m AS status_message;

-- ============================================================
-- [4] 验证查询
-- ============================================================

-- 4.1 基础表数据量（每表应 >= 30）
SELECT 'sys_role' AS tbl, COUNT(*) AS cnt FROM sys_role
UNION ALL SELECT 'sys_user', COUNT(*) FROM sys_user
UNION ALL SELECT 'goods_category', COUNT(*) FROM goods_category
UNION ALL SELECT 'supplier', COUNT(*) FROM supplier
UNION ALL SELECT 'warehouse', COUNT(*) FROM warehouse
UNION ALL SELECT 'goods', COUNT(*) FROM goods;

-- 4.2 明细关联记录数（合计应 >= 200）
SELECT
    (SELECT COUNT(*) FROM inbound_item)   AS inbound_item,
    (SELECT COUNT(*) FROM outbound_item)  AS outbound_item,
    (SELECT COUNT(*) FROM stocktake_item) AS stocktake_item,
    (SELECT COUNT(*) FROM transfer_item)  AS transfer_item,
    (SELECT COUNT(*) FROM stock_batch)    AS stock_batch;

SELECT
    (SELECT COUNT(*) FROM inbound_item)
  + (SELECT COUNT(*) FROM outbound_item)
  + (SELECT COUNT(*) FROM stocktake_item)
  + (SELECT COUNT(*) FROM transfer_item)
  + (SELECT COUNT(*) FROM stock_batch)    AS total_associated_records;

-- 4.3 视图结果（实时库存、预警、出入库汇总、成本批次）
SELECT * FROM v_stock_overview LIMIT 10;
SELECT * FROM v_stock_warning LIMIT 10;
SELECT * FROM v_inout_summary LIMIT 10;
SELECT * FROM v_stock_batch_cost LIMIT 10;

-- 4.4 库存数据 / 盘点记录 / 预警记录
SELECT * FROM stock ORDER BY warehouse_id, goods_id LIMIT 20;
SELECT so.order_no, si.goods_id, si.book_quantity, si.actual_quantity, si.diff_quantity, si.diff_type
FROM stocktake_order so JOIN stocktake_item si ON so.stocktake_id = si.stocktake_id;
SELECT * FROM stock_alert ORDER BY alert_id LIMIT 20;

-- 4.5 统计 SQL（供应商供货金额 / 出入库汇总 / 盘点盈亏 / 领料回料）
-- 各供应商供货金额
SELECT s.supplier_name, COUNT(DISTINCT io.inbound_id) AS orders, SUM(io.total_amount) AS amount
FROM supplier s JOIN inbound_order io ON io.supplier_id = s.supplier_id
WHERE io.biz_type = 'PURCHASE' AND io.status = 1
GROUP BY s.supplier_name ORDER BY amount DESC LIMIT 10;

-- 出入库总量汇总
SELECT 'IN' AS flow, COUNT(*) AS orders, SUM(ii.quantity) AS qty
FROM inbound_order io JOIN inbound_item ii ON io.inbound_id = ii.inbound_id
UNION ALL
SELECT 'OUT', COUNT(*), SUM(oi.quantity)
FROM outbound_order oo JOIN outbound_item oi ON oo.outbound_id = oi.outbound_id;

-- 盘点盈亏汇总
SELECT diff_type, COUNT(*) AS cnt, SUM(diff_quantity) AS total_diff
FROM stocktake_item GROUP BY diff_type;

-- 领料、回料单据统计
SELECT io.biz_type, COUNT(*) AS orders, SUM(ii.quantity) AS qty
FROM inbound_order io JOIN inbound_item ii ON io.inbound_id = ii.inbound_id
WHERE io.biz_type = 'MATERIAL_RETURN' GROUP BY io.biz_type
UNION ALL
SELECT oo.biz_type, COUNT(*), SUM(oi.quantity)
FROM outbound_order oo JOIN outbound_item oi ON oo.outbound_id = oi.outbound_id
WHERE oo.biz_type = 'MATERIAL_ISSUE' GROUP BY oo.biz_type;

-- 清理临时表
DROP TEMPORARY TABLE IF EXISTS nums;

-- 恢复安全更新模式
SET SQL_SAFE_UPDATES = 1;
