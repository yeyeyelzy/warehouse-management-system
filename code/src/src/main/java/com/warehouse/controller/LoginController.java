package com.warehouse.controller;

import com.warehouse.entity.SysUser;
import com.warehouse.service.AuthService;
import com.warehouse.util.BusinessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

import javax.servlet.http.HttpSession;
import javax.servlet.http.HttpServletRequest;
import java.util.Set;

/**
 * 登录控制器
 */
@Controller
public class LoginController {
    private final AuthService authService;

    public LoginController(AuthService authService) {
        this.authService = authService;
    }

    @GetMapping({"/", "/login"})
    public String loginPage() {
        return "login";
    }

    @PostMapping("/login")
    public String login(@RequestParam String username,
                        @RequestParam String password,
                        HttpServletRequest request,
                        RedirectAttributes redirectAttributes) {
        try {
            SysUser user = authService.login(username, password);
            // 根据roleId查询权限编码集合
            Set<String> permissionSet = authService.getPermissionCodesByRoleId(user.getRoleId());
            HttpSession session = request.getSession();
            request.changeSessionId();
            user.setPassword(null);
            session.setAttribute("loginUser", user);
            // 把该角色拥有的全部权限编码存入session
            session.setAttribute("permissionCodes", permissionSet);
            return "redirect:/home";
        } catch (BusinessException e) {
            redirectAttributes.addFlashAttribute("error", e.getMessage());
            return "redirect:/login";
        }
    }

    @GetMapping("/logout")
    public String logout(HttpSession session) {
        session.invalidate();
        return "redirect:/login";
    }

    @GetMapping("/home")
    public String home(Model model, HttpSession session) {
        model.addAttribute("user", session.getAttribute("loginUser"));
        return "home";
    }

    @RequestMapping(path = "/noPermission", method = {RequestMethod.GET, RequestMethod.POST})
    public String noPermission(){
        // 返回thymeleaf页面noPermission.html，提示“您没有该操作权限，禁止访问”
        return "noPermission";
    }

}
