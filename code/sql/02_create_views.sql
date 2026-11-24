-- ============================================================
-- 仓库管理系统数据库 - 视图 + 统计查询脚本
-- MySQL 8.0 / 依赖 01_create_tables.sql（需先建表）
-- 内容：4 个视图（含 2 个必选）+ 8 条答辩演示统计 SQL
-- 说明：视图均含 DROP VIEW IF EXISTS，支持重复执行；
--       统计 SQL 为普通 SELECT 查询，可反复执行。
-- 执行方式：mysql -u root -p < 02_create_views.sql
-- ============================================================

-- ------------------------------------------------------------
-- 业务类型(biz_type)取值约定（统计 SQL 依赖，与后续测试数据保持一致）
--   入库 inbound_order.biz_type：
--     PURCHASE         采购入库
--     SALE_RETURN      销售退货入库
--     MATERIAL_RETURN  回料入库
--     STOCKTAKE_GAIN   盘盈入库
--     TRANSFER_IN      调拨入库
--   出库 outbound_order.biz_type：
--     SALE             销售出库
--     MATERIAL_ISSUE   领料出库
--     PURCHASE_RETURN  采购退货出库
--     STOCKTAKE_LOSS   盘亏出库
--     TRANSFER_OUT     调拨出库
--   盘点差异 diff_type：GAIN(盘盈) / LOSS(盘亏) / NONE(无差异)
--   单据状态 status：0待审核 / 1已审核 / 2作废（统计仅计 status=1）
-- ------------------------------------------------------------

USE warehouse_db;

-- ============================================================
-- 第一部分：视图
-- ============================================================

-- ------------------------------------------------------------
-- 【必选视图 1】当前实时库存视图 v_stock_overview
-- 业务用途：实时库存总览，展示货品、分类、仓库、当前库存数量、
--           库存占用资金、上下限阈值、计价方式及实时库存状态
--           （NORMAL 正常 / LOW 低于下限 / OVER 高于上限）
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_stock_overview;
CREATE VIEW v_stock_overview AS
SELECT
    s.stock_id,
    g.goods_code,
    g.goods_name,
    g.spec,
    g.unit,
    c.category_name,
    w.warehouse_id,
    w.warehouse_name,
    s.quantity AS stock_quantity,
    s.total_cost AS occupied_cost,
    g.lower_limit,
    g.upper_limit,
    g.cost_method,
    CASE
        WHEN s.quantity < g.lower_limit THEN 'LOW'
        WHEN s.quantity > g.upper_limit THEN 'OVER'
        ELSE 'NORMAL'
    END AS stock_status
FROM stock s
JOIN goods g ON s.goods_id = g.goods_id
JOIN warehouse w ON s.warehouse_id = w.warehouse_id
LEFT JOIN goods_category c ON g.category_id = c.category_id;

-- ------------------------------------------------------------
-- 【必选视图 2】超储/短缺预警货品视图 v_stock_warning
-- 业务用途：实时筛选超储（高于上限）与短缺（低于下限）的货品，
--           输出预警类型（LOW 短缺 / OVER 超储）与超出/缺口数量，
--           供补货或促销决策使用。
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_stock_warning;
CREATE VIEW v_stock_warning AS
SELECT
    s.stock_id,
    g.goods_code,
    g.goods_name,
    g.spec,
    g.unit,
    w.warehouse_name,
    s.quantity AS current_quantity,
    g.lower_limit,
    g.upper_limit,
    CASE
        WHEN s.quantity < g.lower_limit THEN 'LOW'
        WHEN s.quantity > g.upper_limit THEN 'OVER'
    END AS warn_type,
    CASE
        WHEN s.quantity < g.lower_limit THEN g.lower_limit - s.quantity
        WHEN s.quantity > g.upper_limit THEN s.quantity - g.upper_limit
        ELSE 0
    END AS warn_quantity
FROM stock s
JOIN goods g ON s.goods_id = g.goods_id
JOIN warehouse w ON s.warehouse_id = w.warehouse_id
WHERE s.quantity < g.lower_limit OR s.quantity > g.upper_limit;

-- ------------------------------------------------------------
-- 【辅助视图 3】出入库明细汇总视图 v_inout_summary
-- 业务用途：将入库明细与出库明细合并，用 flow_type(IN/OUT) 区分方向，
--           出库行的 unit_cost/total_cost 即 FIFO/LIFO 计算出的成本，
--           支持按货品、计价方式、时间段查询出入库成本。
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_inout_summary;
CREATE VIEW v_inout_summary AS
SELECT
    'IN' AS flow_type,
    io.order_no,
    io.biz_type,
    io.inbound_date AS flow_date,
    w.warehouse_name,
    g.goods_code,
    g.goods_name,
    g.cost_method,
    ii.quantity,
    ii.unit_price,
    ii.amount,
    CAST(NULL AS DECIMAL(12,2)) AS unit_cost,
    CAST(NULL AS DECIMAL(12,2)) AS total_cost
FROM inbound_order io
JOIN inbound_item ii ON io.inbound_id = ii.inbound_id
JOIN goods g ON ii.goods_id = g.goods_id
JOIN warehouse w ON io.warehouse_id = w.warehouse_id
UNION ALL
SELECT
    'OUT' AS flow_type,
    oo.order_no,
    oo.biz_type,
    oo.outbound_date AS flow_date,
    w.warehouse_name,
    g.goods_code,
    g.goods_name,
    g.cost_method,
    oi.quantity,
    CAST(NULL AS DECIMAL(12,2)) AS unit_price,
    CAST(NULL AS DECIMAL(12,2)) AS amount,
    oi.unit_cost,
    oi.total_cost
FROM outbound_order oo
JOIN outbound_item oi ON oo.outbound_id = oi.outbound_id
JOIN goods g ON oi.goods_id = g.goods_id
JOIN warehouse w ON oo.warehouse_id = w.warehouse_id;

-- ------------------------------------------------------------
-- 【辅助视图 4】FIFO/LIFO 成本批次视图 v_stock_batch_cost
-- 业务用途：展示各成本批次剩余数量、单位成本、剩余成本与入库日期，
--           支撑 FIFO（inbound_date 升序扣减）、LIFO（降序扣减）
--           出库成本核算查询。
-- ------------------------------------------------------------
DROP VIEW IF EXISTS v_stock_batch_cost;
CREATE VIEW v_stock_batch_cost AS
SELECT
    b.batch_id,
    b.batch_no,
    b.warehouse_id,
    w.warehouse_name,
    b.goods_id,
    g.goods_code,
    g.goods_name,
    g.cost_method,
    b.quantity AS remain_quantity,
    b.unit_cost,
    b.remaining_cost AS remain_cost,
    b.inbound_date
FROM stock_batch b
JOIN goods g ON b.goods_id = g.goods_id
JOIN warehouse w ON b.warehouse_id = w.warehouse_id;

-- ============================================================
-- 第二部分：答辩演示统计 SQL（8 条，覆盖 6 类场景）
-- 说明：以下为可直接执行的查询语句，时间段为示例，演示时可替换。
-- ============================================================

-- ------------------------------------------------------------
-- 【统计SQL 1】任意时间段入库总量汇总（场景① 出入库总量汇总）
-- 演示用途：按货品汇总指定时间段内的入库总量与入库金额，
--           满足“任意时间段库存查询”需求。
-- ------------------------------------------------------------
SELECT
    g.goods_code,
    g.goods_name,
    SUM(ii.quantity) AS total_in_quantity,
    SUM(ii.amount)    AS total_in_amount
FROM inbound_order io
JOIN inbound_item ii ON io.inbound_id = ii.inbound_id
JOIN goods g ON ii.goods_id = g.goods_id
WHERE io.inbound_date BETWEEN '2026-01-01 00:00:00' AND '2026-08-31 23:59:59'
  AND io.status = 1
GROUP BY g.goods_code, g.goods_name
ORDER BY total_in_quantity DESC;

-- ------------------------------------------------------------
-- 【统计SQL 2】任意时间段出库总量汇总（场景① 出入库总量汇总）
-- 演示用途：按货品汇总指定时间段内的出库总量与出库成本，
--           出库成本 unit_cost/total_cost 由 FIFO/LIFO 计算，支持成本分析。
-- ------------------------------------------------------------
SELECT
    g.goods_code,
    g.goods_name,
    g.cost_method,
    SUM(oi.quantity)   AS total_out_quantity,
    SUM(oi.total_cost) AS total_out_cost
FROM outbound_order oo
JOIN outbound_item oi ON oo.outbound_id = oi.outbound_id
JOIN goods g ON oi.goods_id = g.goods_id
WHERE oo.outbound_date BETWEEN '2026-01-01 00:00:00' AND '2026-08-31 23:59:59'
  AND oo.status = 1
GROUP BY g.goods_code, g.goods_name, g.cost_method
ORDER BY total_out_cost DESC;

-- ------------------------------------------------------------
-- 【统计SQL 3】各供应商供货金额统计（场景② 供应商供货金额）
-- 演示用途：按供应商汇总采购入库单据数与金额，展示供应商供货金额排名。
-- ------------------------------------------------------------
SELECT
    s.supplier_id,
    s.supplier_name,
    COUNT(DISTINCT io.inbound_id) AS supply_order_count,
    SUM(io.total_amount)          AS supply_amount
FROM supplier s
JOIN inbound_order io ON io.supplier_id = s.supplier_id
WHERE io.biz_type = 'PURCHASE'
  AND io.status = 1
GROUP BY s.supplier_id, s.supplier_name
ORDER BY supply_amount DESC;

-- ------------------------------------------------------------
-- 【统计SQL 4】月度库存资金占用汇总（场景③ 库存资金占用）
-- 演示用途：按入库月份汇总当前仍占用的库存资金
--           （各批次剩余数量 × 单位成本），反映资金占用分布。
-- ------------------------------------------------------------
SELECT
    DATE_FORMAT(b.inbound_date, '%Y-%m') AS month,
    SUM(b.remaining_cost)         AS occupied_capital
FROM stock_batch b
WHERE b.quantity > 0
GROUP BY DATE_FORMAT(b.inbound_date, '%Y-%m')
ORDER BY month;

-- ------------------------------------------------------------
-- 【统计SQL 5】滞销货品统计（场景④ 滞销货品）
-- 演示用途：统计近90天内无出库记录（出库量为0）且当前仍有库存的货品，
--           用于库存清理与滞销预警。
-- ------------------------------------------------------------
SELECT
    g.goods_id,
    g.goods_code,
    g.goods_name,
    st.current_stock,
    COALESCE(sale.sold_90d, 0) AS sold_90d
FROM goods g
LEFT JOIN (
    SELECT goods_id, SUM(quantity) AS current_stock
    FROM stock
    GROUP BY goods_id
) st ON st.goods_id = g.goods_id
LEFT JOIN (
    SELECT oi.goods_id, SUM(oi.quantity) AS sold_90d
    FROM outbound_item oi
    JOIN outbound_order oo ON oo.outbound_id = oi.outbound_id
    WHERE oo.outbound_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
      AND oo.status = 1
    GROUP BY oi.goods_id
) sale ON sale.goods_id = g.goods_id
WHERE st.current_stock > 0
  AND (sale.sold_90d IS NULL OR sale.sold_90d = 0)
ORDER BY st.current_stock DESC;

-- ------------------------------------------------------------
-- 【统计SQL 6】盘点盈亏汇总（场景⑤ 盘点盈亏）
-- 演示用途：按仓库汇总盘盈、盘亏数量与次数，反映账实差异情况。
-- ------------------------------------------------------------
SELECT
    so.warehouse_id,
    w.warehouse_name,
    SUM(CASE WHEN si.diff_type = 'GAIN' THEN si.diff_quantity ELSE 0 END) AS gain_quantity,
    SUM(CASE WHEN si.diff_type = 'LOSS' THEN -si.diff_quantity ELSE 0 END) AS loss_quantity,
    SUM(CASE WHEN si.diff_type = 'GAIN' THEN 1 ELSE 0 END) AS gain_count,
    SUM(CASE WHEN si.diff_type = 'LOSS' THEN 1 ELSE 0 END) AS loss_count
FROM stocktake_order so
JOIN stocktake_item si ON so.stocktake_id = si.stocktake_id
JOIN warehouse w ON so.warehouse_id = w.warehouse_id
WHERE so.status = 1
GROUP BY so.warehouse_id, w.warehouse_name
ORDER BY loss_quantity DESC;

-- ------------------------------------------------------------
-- 【统计SQL 7】领料单据统计（场景⑥ 领料、回料单据）
-- 演示用途：按货品汇总领料出库数量与成本，反映生产领用情况。
-- ------------------------------------------------------------
SELECT
    g.goods_code,
    g.goods_name,
    SUM(oi.quantity)   AS issue_quantity,
    SUM(oi.total_cost) AS issue_cost
FROM outbound_order oo
JOIN outbound_item oi ON oo.outbound_id = oi.outbound_id
JOIN goods g ON oi.goods_id = g.goods_id
WHERE oo.biz_type = 'MATERIAL_ISSUE'
  AND oo.status = 1
GROUP BY g.goods_code, g.goods_name
ORDER BY issue_quantity DESC;

-- ------------------------------------------------------------
-- 【统计SQL 8】回料单据统计（场景⑥ 领料、回料单据）
-- 演示用途：按货品汇总回料入库数量与金额，反映车间退回物料情况。
-- ------------------------------------------------------------
SELECT
    g.goods_code,
    g.goods_name,
    SUM(ii.quantity) AS return_quantity,
    SUM(ii.amount)   AS return_amount
FROM inbound_order io
JOIN inbound_item ii ON io.inbound_id = ii.inbound_id
JOIN goods g ON ii.goods_id = g.goods_id
WHERE io.biz_type = 'MATERIAL_RETURN'
  AND io.status = 1
GROUP BY g.goods_code, g.goods_name
ORDER BY return_quantity DESC;
