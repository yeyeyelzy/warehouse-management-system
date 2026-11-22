package com.warehouse.entity;

import lombok.Data;

/**
 * 系统用户实体（对应 sys_user 表）
 */
@Data
public class SysUser {
    private Integer userId;
    private String username;
    private String password;
    private String realName;
    private Integer roleId;
}
