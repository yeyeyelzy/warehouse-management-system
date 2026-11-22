package com.warehouse.util;

/**
 * 业务异常：用于存储过程返回失败时抛出，提示用户友好的错误信息
 */
public class BusinessException extends RuntimeException {

    public BusinessException(String message) {
        super(message);
    }
}
