package com.warehouse.util;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * 存储过程返回结果封装
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class ProcedureResult {
    /** 状态码：0 成功，1 失败 */
    private Integer statusCode;
    /** 返回消息 */
    private String statusMsg;
    /** 出库成本（仅出库核算过程使用） */
    private BigDecimal outTotalCost;
}
