package com.warehouse.entity;

import lombok.Data;

/**
 * 供应商实体（对应 supplier 表）
 */
@Data
public class Supplier {
    private Integer supplierId;
    private String supplierName;
    private String contactName;
    private String phone;
    private String address;
    private String email;
    private Integer status;
}
