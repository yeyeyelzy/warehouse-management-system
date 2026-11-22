package com.warehouse.mapper;

import org.apache.ibatis.annotations.Options;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.mapping.StatementType;

import java.util.Map;

/**
 * 存储过程调用 DAO 层
 *
 * 说明：
 *  - 入库/出库/盘点/调拨业务逻辑主体在 MySQL 存储过程侧（含事务、异常回滚）；
 *  - Java 仅负责传入参数、调用存储过程、读取 OUT 状态码与消息；
 *  - 采用 MyBatis CALLABLE 语句类型，OUT 参数执行后写回 params Map。
 */
public interface ProcedureMapper {

    // ① 货品入库 sp_inbound
    @Select("{CALL sp_inbound(" +
            "#{warehouseId, mode=IN, jdbcType=INTEGER}, " +
            "#{goodsId, mode=IN, jdbcType=INTEGER}, " +
            "#{quantity, mode=IN, jdbcType=DECIMAL}, " +
            "#{unitPrice, mode=IN, jdbcType=DECIMAL}, " +
            "#{operatorId, mode=IN, jdbcType=INTEGER}, " +
            "#{supplierId, mode=IN, jdbcType=INTEGER}, " +
            "#{bizType, mode=IN, jdbcType=VARCHAR}, " +
            "#{statusCode, mode=OUT, jdbcType=INTEGER}, " +
            "#{statusMsg, mode=OUT, jdbcType=VARCHAR})}")
    @Options(statementType = StatementType.CALLABLE)
    void callInbound(Map<String, Object> params);

    // ② 出库成本核算 sp_outbound_cost（FIFO/LIFO）
    @Select("{CALL sp_outbound_cost(" +
            "#{warehouseId, mode=IN, jdbcType=INTEGER}, " +
            "#{goodsId, mode=IN, jdbcType=INTEGER}, " +
            "#{quantity, mode=IN, jdbcType=DECIMAL}, " +
            "#{operatorId, mode=IN, jdbcType=INTEGER}, " +
            "#{bizType, mode=IN, jdbcType=VARCHAR}, " +
            "#{statusCode, mode=OUT, jdbcType=INTEGER}, " +
            "#{statusMsg, mode=OUT, jdbcType=VARCHAR}, " +
            "#{outTotalCost, mode=OUT, jdbcType=DECIMAL})}")
    @Options(statementType = StatementType.CALLABLE)
    void callOutboundCost(Map<String, Object> params);

    // ③ 库存盘点 sp_stocktake
    @Select("{CALL sp_stocktake(" +
            "#{warehouseId, mode=IN, jdbcType=INTEGER}, " +
            "#{goodsId, mode=IN, jdbcType=INTEGER}, " +
            "#{actualQuantity, mode=IN, jdbcType=DECIMAL}, " +
            "#{operatorId, mode=IN, jdbcType=INTEGER}, " +
            "#{statusCode, mode=OUT, jdbcType=INTEGER}, " +
            "#{statusMsg, mode=OUT, jdbcType=VARCHAR})}")
    @Options(statementType = StatementType.CALLABLE)
    void callStocktake(Map<String, Object> params);

    // ④ 批量调拨 sp_transfer（明细 JSON）
    @Select("{CALL sp_transfer(" +
            "#{fromWarehouseId, mode=IN, jdbcType=INTEGER}, " +
            "#{toWarehouseId, mode=IN, jdbcType=INTEGER}, " +
            "#{operatorId, mode=IN, jdbcType=INTEGER}, " +
            "#{itemsJson, mode=IN, jdbcType=VARCHAR}, " +
            "#{statusCode, mode=OUT, jdbcType=INTEGER}, " +
            "#{statusMsg, mode=OUT, jdbcType=VARCHAR})}")
    @Options(statementType = StatementType.CALLABLE)
    void callTransfer(Map<String, Object> params);
}
