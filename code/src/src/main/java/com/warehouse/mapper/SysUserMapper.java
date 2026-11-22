package com.warehouse.mapper;

import com.warehouse.entity.SysUser;
import org.apache.ibatis.annotations.Select;

/**
 * 用户 DAO 层
 */
public interface SysUserMapper {

    @Select("SELECT * FROM sys_user WHERE username = #{username}")
    SysUser findByUsername(String username);
}
