package com.warehouse.entity;

import lombok.Data;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 库存预警记录实体（对应 stock_alert 表，由触发器自动生成）
 */
@Data
public class StockAlert {
    private Integer alertId;
    private Integer goodsId;
    private Integer warehouseId;
    private String alertType;      // OVER 超储 / LOW 短缺
    private BigDecimal currentQuantity;
    private BigDecimal threshold;
    private LocalDateTime alertTime;
    private Integer status;
}
