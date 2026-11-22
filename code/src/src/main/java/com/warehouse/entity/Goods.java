package com.warehouse.entity;

import lombok.Data;

import java.math.BigDecimal;

/**
 * 货品基础信息实体（对应 goods 表）
 */
@Data
public class Goods {
    private Integer goodsId;
    private String goodsCode;
    private String goodsName;
    private String spec;
    private String unit;
    private Integer categoryId;
    private String costMethod;   // FIFO / LIFO
    private BigDecimal upperLimit;
    private BigDecimal lowerLimit;
    private BigDecimal price;
    private Integer status;
}
