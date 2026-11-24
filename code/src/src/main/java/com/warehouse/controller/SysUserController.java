package com.warehouse.controller;

import com.warehouse.entity.SysUser;
import com.warehouse.mapper.SysUserMapper;
import com.warehouse.util.BusinessException;
import com.warehouse.util.PasswordUtil;
import com.warehouse.util.RequirePermission;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import java.util.List;

@Controller
@RequestMapping("/sys/user")
public class SysUserController {

    private final SysUserMapper sysUserMapper;
    public SysUserController(SysUserMapper sysUserMapper) {
        this.sysUserMapper = sysUserMapper;
    }

    @GetMapping
    @RequirePermission("user:manage")
    public String userList(Model model){
        List<SysUser> list = sysUserMapper.selectAllUser();
        model.addAttribute("userList", list);
        return "sys/user";
    }

    @PostMapping("/add")
    @RequirePermission("user:manage")
    public String add(SysUser sysUser, RedirectAttributes ra){
        if (sysUser.getPassword() == null || sysUser.getPassword().trim().isEmpty()) {
            throw new BusinessException("密码不能为空");
        }
        if(sysUser.getStatus() == null) sysUser.setStatus(1);
        sysUser.setPassword(PasswordUtil.encode(sysUser.getPassword()));
        sysUserMapper.insertUser(sysUser);
        ra.addFlashAttribute("msg","新增成功");
        return "redirect:/sys/user";
    }

    @PostMapping("/update")
    @RequirePermission("user:manage")
    public String update(SysUser sysUser, RedirectAttributes ra){
        if (sysUser.getPassword() != null && !sysUser.getPassword().trim().isEmpty()) {
            sysUser.setPassword(PasswordUtil.encode(sysUser.getPassword()));
        }
        sysUserMapper.updateUser(sysUser);
        ra.addFlashAttribute("msg","修改成功");
        return "redirect:/sys/user";
    }

    @PostMapping("/del/{userId}")
    @RequirePermission("user:manage")
    public String del(@PathVariable Integer userId, RedirectAttributes ra){
        sysUserMapper.deleteUser(userId);
        ra.addFlashAttribute("msg","删除成功");
        return "redirect:/sys/user";
    }
}
