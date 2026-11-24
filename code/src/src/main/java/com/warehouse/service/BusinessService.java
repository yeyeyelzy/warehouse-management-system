package com.warehouse.service;

import com.warehouse.mapper.ProcedureMapper;
import com.warehouse.util.BusinessException;
import com.warehouse.util.ProcedureResult;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

/**
 * 核心业务服务：入库 / 出库(FIFO/LIFO) / 盘点 / 调拨
 *
 * 设计说明：
 *  - 业务逻辑主体在 MySQL 存储过程侧（含事务、异常回滚）；
 *  - 本层仅做参数校验、业务组装、调用存储过程、读取 OUT 状态码与消息；
 *  - 不重复编写库存更新逻辑（由触发器自动完成）、不重写成本算法（由存储过程完成）。
 */
@Service
public class BusinessService {

    private final ProcedureMapper procedureMapper;

    public BusinessService(ProcedureMapper procedureMapper) {
        this.procedureMapper = procedureMapper;
    }

    /**
     * 入库（采购入库 / 销售退货 / 回料 统一走 sp_inbound，用 bizType 区分）
     */
    public ProcedureResult inbound(Integer warehouseId, Integer goodsId, BigDecimal quantity,
                          BigDecimal unitPrice, Integer operatorId, Integer supplierId, String bizType) {
        requireNotNull(warehouseId, "入库仓库");
        requireNotNull(goodsId, "货品");
        requirePositive(quantity, "入库数量");
        requireNonNegative(unitPrice, "入库单价");
        Map<String, Object> params = new HashMap<>();
        params.put("warehouseId", warehouseId);
        params.put("goodsId", goodsId);
        params.put("quantity", quantity);
        params.put("unitPrice", unitPrice);
        params.put("operatorId", operatorId);
        params.put("supplierId", supplierId);
        params.put("bizType", bizType);
        params.put("statusCode", null);
        params.put("statusMsg", null);

        procedureMapper.callInbound(params);
        return checkResult(params, null);
    }

    /**
     * 出库（销售出库 / 领料 / 采购退货 统一走 sp_outbound_cost，用 bizType 区分）
     */
    public ProcedureResult outbound(Integer warehouseId, Integer goodsId, BigDecimal quantity,
                                    Integer operatorId, String bizType) {
        requireNotNull(warehouseId, "出库仓库");
        requireNotNull(goodsId, "货品");
        requirePositive(quantity, "出库数量");
        Map<String, Object> params = new HashMap<>();
        params.put("warehouseId", warehouseId);
        params.put("goodsId", goodsId);
        params.put("quantity", quantity);
        params.put("operatorId", operatorId);
        params.put("bizType", bizType);
        params.put("statusCode", null);
        params.put("statusMsg", null);
        params.put("outTotalCost", null);

        procedureMapper.callOutboundCost(params);
        return checkResult(params, "outTotalCost");
    }

    /**
     * 库存盘点（盘盈/盘亏）
     */
    public ProcedureResult stocktake(Integer warehouseId, Integer goodsId, BigDecimal actualQuantity, Integer operatorId) {
        Map<String, Object> params = new HashMap<>();
        params.put("warehouseId", warehouseId);
        params.put("goodsId", goodsId);
        params.put("actualQuantity", actualQuantity);
        params.put("operatorId", operatorId);
        params.put("statusCode", null);
        params.put("statusMsg", null);

        procedureMapper.callStocktake(params);
        return checkResult(params, null);
    }

    /**
     * 仓库调拨（跨仓库，多货品 JSON 明细）
     */
    public ProcedureResult transfer(Integer fromWarehouseId, Integer toWarehouseId, Integer operatorId, String itemsJson) {
        Map<String, Object> params = new HashMap<>();
        params.put("fromWarehouseId", fromWarehouseId);
        params.put("toWarehouseId", toWarehouseId);
        params.put("operatorId", operatorId);
        params.put("itemsJson", itemsJson);
        params.put("statusCode", null);
        params.put("statusMsg", null);

        procedureMapper.callTransfer(params);
        return checkResult(params, null);
    }

    /**
     * 校验存储过程返回结果，失败抛出业务异常
     */
    private ProcedureResult checkResult(Map<String, Object> params, String extraKey) {
        Integer statusCode = (Integer) params.get("statusCode");
        String statusMsg = (String) params.get("statusMsg");
        BigDecimal extra = extraKey == null ? null : (BigDecimal) params.get(extraKey);

        ProcedureResult result = new ProcedureResult(statusCode, statusMsg, extra);
        if (statusCode == null || statusCode != 0) {
            throw new BusinessException(statusMsg == null ? "业务处理失败" : statusMsg);
        }
        return result;
    }

    private void requireNotNull(Integer value, String name) {
        if (value == null) {
            throw new BusinessException(name + "不能为空");
        }
    }

    private void requirePositive(BigDecimal value, String name) {
        if (value == null || value.compareTo(BigDecimal.ZERO) <= 0) {
            throw new BusinessException(name + "必须大于0");
        }
    }

    private void requireNonNegative(BigDecimal value, String name) {
        if (value == null || value.compareTo(BigDecimal.ZERO) < 0) {
            throw new BusinessException(name + "不能为负");
        }
    }
}
