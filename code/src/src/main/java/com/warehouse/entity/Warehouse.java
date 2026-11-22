package com.warehouse.entity;

import lombok.Data;

/**
 * 仓库实体（对应 warehouse 表）
 */
@Data
public class Warehouse {
    private Integer warehouseId;
    private String warehouseName;
    private String location;
    private String manager;
    private String phone;
}
