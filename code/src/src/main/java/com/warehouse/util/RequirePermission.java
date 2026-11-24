package com.warehouse.util;

import java.lang.annotation.*;

/**
 * 接口权限注解，标注Controller方法访问需要的权限编码
 */
@Target({ElementType.METHOD})
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RequirePermission {
    String value();
}
