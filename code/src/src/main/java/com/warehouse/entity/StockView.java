package com.warehouse.entity;

import lombok.Data;

import java.math.BigDecimal;

/**
 * 库存总览视图实体（对应视图 v_stock_overview）
 */
@Data
public class StockView {
    private Integer stockId;
    private String goodsCode;
    private String goodsName;
    private String spec;
    private String unit;
    private String categoryName;
    private Integer warehouseId;
    private String warehouseName;
    private BigDecimal stockQuantity;
    private BigDecimal occupiedCost;
    private BigDecimal lowerLimit;
    private BigDecimal upperLimit;
    private String costMethod;
    private String stockStatus;   // NORMAL / LOW / OVER
}
