package com.warehouse.service;

import com.warehouse.entity.SysUser;
import com.warehouse.mapper.SysUserMapper;
import com.warehouse.util.BusinessException;
import org.springframework.stereotype.Service;

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
     * 登录校验
     */
    public SysUser login(String username, String password) {
        if (username == null || username.trim().isEmpty()) {
            throw new BusinessException("请输入用户名");
        }
        SysUser user = sysUserMapper.findByUsername(username.trim());
        if (user == null) {
            throw new BusinessException("用户不存在");
        }
        if (!user.getPassword().equals(password)) {
            throw new BusinessException("密码错误");
        }
        return user;
    }
}
