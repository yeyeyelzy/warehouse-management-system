package com.warehouse.service;

import com.warehouse.entity.SysUser;
import com.warehouse.mapper.SysUserMapper;
import com.warehouse.util.BusinessException;
import com.warehouse.util.PasswordUtil;
import org.springframework.stereotype.Service;
import java.util.Set;

/**
 * 登录认证服务
 */
@Service
public class AuthService {
    private final SysUserMapper sysUserMapper;

    public AuthService(SysUserMapper sysUserMapper) {
        this.sysUserMapper = sysUserMapper;
    }

    /**
     * 登录校验：账号、密码、账号状态status
     */
    public SysUser login(String username, String password) {
        if (username == null || username.trim().isEmpty()) {
            throw new BusinessException("请输入用户名");
        }
        SysUser user = sysUserMapper.findByUsername(username.trim());
        if (user == null) {
            throw new BusinessException("用户不存在");
        }
        //校验账号是否禁用 status=0禁用
        if(Integer.valueOf(0).equals(user.getStatus())){
            throw new BusinessException("该账号已被禁用，禁止登录");
        }
        if (!PasswordUtil.matches(password, user.getPassword())) {
            throw new BusinessException("密码错误");
        }
        user.setPassword(null);
        return user;
    }

    /**
     * 根据角色id，获取该角色全部权限编码集合
     */
    public Set<String> getPermissionCodesByRoleId(Integer roleId){
        return sysUserMapper.selectPermissionCodesByRoleId(roleId);
    }
}
