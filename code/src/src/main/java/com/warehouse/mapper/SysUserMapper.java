package com.warehouse.mapper;

import com.warehouse.entity.SysUser;
import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Set;

/**
 * 用户 DAO 层
 */
public interface SysUserMapper {

    @Select("SELECT * FROM sys_user WHERE username = #{username}")
    SysUser findByUsername(String username);

    /**
     * 根据角色id，查询该角色所有权限编码permission_code
     */
    @Select("SELECT DISTINCT p.permission_code " +
            "FROM sys_role_permission rp " +
            "INNER JOIN sys_permission p ON rp.permission_id = p.permission_id " +
            "WHERE rp.role_id = #{roleId}")
    Set<String> selectPermissionCodesByRoleId(Integer roleId);

    //======== 用户管理新增下面4个注解SQL ========
    @Select("SELECT * FROM sys_user")
    List<SysUser> selectAllUser();

    @Insert("INSERT INTO sys_user(username,password,real_name,role_id,status) " +
            "VALUES(#{username},#{password},#{realName},#{roleId},#{status})")
    int insertUser(SysUser sysUser);

    @Update("UPDATE sys_user SET username=#{username},password=COALESCE(NULLIF(#{password}, ''), password)," +
            "real_name=#{realName},role_id=#{roleId},status=#{status} " +
            "WHERE user_id=#{userId}")
    int updateUser(SysUser sysUser);

    @Delete("DELETE FROM sys_user WHERE user_id=#{userId}")
    int deleteUser(@Param("userId") Integer userId);
}
