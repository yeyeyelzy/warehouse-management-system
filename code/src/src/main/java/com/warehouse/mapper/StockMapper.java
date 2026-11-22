package com.warehouse.mapper;

import com.warehouse.entity.StockAlert;
import com.warehouse.entity.StockView;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;
import java.util.Map;

/**
 * 库存 / 预警 / 统计 DAO 层
 * 查询基于视图 v_stock_overview、v_stock_warning，统计复用 SQL 脚本中的统计语句
 */
public interface StockMapper {

    // 库存总览（视图 v_stock_overview）
    @Select("SELECT * FROM v_stock_overview ORDER BY warehouse_id, goods_code")
    List<StockView> listOverview();

    // 超储/短缺预警货品（视图 v_stock_warning）
    @Select("SELECT * FROM v_stock_warning ORDER BY warn_type, goods_code")
    List<Map<String, Object>> listWarning();

    // 预警记录（stock_alert，触发器自动生成）
    @Select("SELECT a.alert_id, a.goods_id, a.warehouse_id, g.goods_name, w.warehouse_name, " +
            "a.alert_type, a.current_quantity, a.threshold, a.alert_time, a.status " +
            "FROM stock_alert a " +
            "JOIN goods g ON a.goods_id = g.goods_id " +
            "JOIN warehouse w ON a.warehouse_id = w.warehouse_id " +
            "ORDER BY a.alert_time DESC")
    List<Map<String, Object>> listAlerts();

    // 统计1：时间段出入库总量汇总
    @Select("SELECT '入库' AS flow_type, COUNT(*) AS orders, COALESCE(SUM(ii.quantity),0) AS qty, COALESCE(SUM(ii.amount),0) AS amount " +
            "FROM inbound_order io JOIN inbound_item ii ON io.inbound_id = ii.inbound_id " +
            "UNION ALL " +
            "SELECT '出库', COUNT(*), COALESCE(SUM(oi.quantity),0), COALESCE(SUM(oi.total_cost),0) " +
            "FROM outbound_order oo JOIN outbound_item oi ON oo.outbound_id = oi.outbound_id")
    List<Map<String, Object>> inoutSummary();

    // 统计2：各供应商供货金额统计
    @Select("SELECT s.supplier_name, COUNT(DISTINCT io.inbound_id) AS orders, SUM(io.total_amount) AS amount " +
            "FROM supplier s JOIN inbound_order io ON io.supplier_id = s.supplier_id " +
            "WHERE io.biz_type = 'PURCHASE' AND io.status = 1 " +
            "GROUP BY s.supplier_name ORDER BY amount DESC")
    List<Map<String, Object>> supplierSupply();

    // 统计3：盘点盈亏汇总
    @Select("SELECT diff_type, COUNT(*) AS cnt, SUM(diff_quantity) AS total_diff " +
            "FROM stocktake_item GROUP BY diff_type")
    List<Map<String, Object>> stocktakeDiff();

    // 查询某仓库某货品的实时库存状态（NORMAL / LOW / OVER）
    @Select("SELECT CASE WHEN s.quantity < g.lower_limit THEN 'LOW' " +
            "WHEN s.quantity > g.upper_limit THEN 'OVER' ELSE 'NORMAL' END " +
            "FROM stock s JOIN goods g ON s.goods_id = g.goods_id " +
            "WHERE s.warehouse_id = #{warehouseId} AND s.goods_id = #{goodsId}")
    String getStockStatus(@Param("warehouseId") Integer warehouseId, @Param("goodsId") Integer goodsId);
}
