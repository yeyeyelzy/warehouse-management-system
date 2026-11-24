package com.warehouse.mapper;

import org.apache.ibatis.annotations.*;
import java.util.List;
import java.util.Map;

@Mapper
public interface SysRolePermMapper {

    // 查询全部角色
    @Select("select * from sys_role")
    List<Map<String,Object>> selectAllRole();

    // 查询全部权限
    @Select("SELECT * FROM sys_permission WHERE permission_code NOT IN ('user:manage', 'role:assign') ORDER BY permission_id")
    List<Map<String,Object>> selectAllPerm();

    // 根据roleId查该角色拥有的权限code集合（登录时用！）
    @Select("SELECT p.permission_code FROM sys_permission p " +
            "JOIN sys_role_permission rp ON p.permission_id = rp.permission_id " +
            "WHERE rp.role_id = #{roleId}")
    List<String> selectPermCodeByRoleId(Integer roleId);

    @Select("SELECT role_id, permission_id FROM sys_role_permission ORDER BY role_id, permission_id")
    List<Map<String,Object>> selectAllGrants();

    // 删除角色旧权限
    @Delete("DELETE rp FROM sys_role_permission rp JOIN sys_permission p ON rp.permission_id = p.permission_id WHERE rp.role_id = #{roleId} AND p.permission_code NOT IN ('user:manage', 'role:assign')")
    void deletePermByRoleId(Integer roleId);

    // 新增一条角色权限
    @Insert("INSERT INTO sys_role_permission(role_id,permission_id) VALUES(#{roleId},#{pid})")
    void insertRolePerm(@Param("roleId") Integer roleId, @Param("pid") Integer pid);
}
