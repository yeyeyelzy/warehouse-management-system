package com.warehouse.controller;

import com.warehouse.mapper.SysRolePermMapper;
import com.warehouse.util.RequirePermission;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;
import com.warehouse.util.BusinessException;

@Controller
@RequestMapping("/sys/role")
public class SysRolePermController {

    private final SysRolePermMapper sysRolePermMapper;
    public SysRolePermController(SysRolePermMapper sysRolePermMapper) {
        this.sysRolePermMapper = sysRolePermMapper;
    }

    @GetMapping
    @RequirePermission("role:assign")
    public String rolePage(Model model){
        List<Map<String,Object>> roleList = sysRolePermMapper.selectAllRole();
        List<Map<String,Object>> permList = sysRolePermMapper.selectAllPerm();
        model.addAttribute("roleList", roleList);
        Map<String, Set<String>> grants = new HashMap<>();
        for (Map<String, Object> grant : sysRolePermMapper.selectAllGrants()) {
            grants.computeIfAbsent(grant.get("role_id").toString(), key -> new HashSet<>())
                  .add(grant.get("permission_id").toString());
        }
        model.addAttribute("grants", grants);
        model.addAttribute("permList", permList);
        return "sys/role";
    }

    @PostMapping("/save")
    @RequirePermission("role:assign")
    @org.springframework.transaction.annotation.Transactional
    public String savePerm(@RequestParam Integer roleId,
                           @RequestParam(required = false) List<Integer> permissionIds,
                           RedirectAttributes ra){
        Set<Integer> allowedIds = new HashSet<>();
        for (Map<String, Object> permission : sysRolePermMapper.selectAllPerm()) {
            allowedIds.add(((Number) permission.get("permission_id")).intValue());
        }
        Set<Integer> selected = permissionIds == null ? Set.of() : new HashSet<>(permissionIds);
        if (!allowedIds.containsAll(selected)) {
            throw new BusinessException("只能分配有效的业务权限");
        }
        sysRolePermMapper.deletePermByRoleId(roleId);
        for (Integer permissionId : selected) {
            sysRolePermMapper.insertRolePerm(roleId, permissionId);
        }
        ra.addFlashAttribute("msg","权限分配保存成功");
        return "redirect:/sys/role";
    }
}
