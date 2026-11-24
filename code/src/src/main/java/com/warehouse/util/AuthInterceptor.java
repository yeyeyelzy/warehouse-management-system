package com.warehouse.util;

import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import javax.servlet.http.HttpSession;
import java.util.Set;

/**
 * 权限拦截器
 * 1.未登录：跳转登录页
 * 2.已登录，读取@RequirePermission注解校验权限
 * 3.越权访问：重定向到提示页面；合法则放行
 */
@Component
public class AuthInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        // 不是Controller方法，直接放行（静态资源等）
        if (!(handler instanceof HandlerMethod)) {
            return true;
        }
        HandlerMethod handlerMethod = (HandlerMethod) handler;

        HttpSession session = request.getSession(false);
        // =========场景1：未登录，拦截跳转登录页 =========
        if (session == null || session.getAttribute("loginUser") == null) {
            response.sendRedirect(request.getContextPath() + "/login");
            return false;
        }

        // 获取当前接口需要的权限注解
        RequirePermission anno = handlerMethod.getMethodAnnotation(RequirePermission.class);
        // 如果接口没有打@RequirePermission注解，代表不需要权限，直接放行
        if (anno == null) {
            return true;
        }
        String needPermission = anno.value();
        @SuppressWarnings("unchecked")
        Set<String> userPermissions = (Set<String>) session.getAttribute("permissionCodes");

        // =========场景2：越权访问，没有该权限 =========
        if(userPermissions == null || !userPermissions.contains(needPermission)){
            // 重定向到无权限提示，也可以自己写一个无权限html页面
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            request.getRequestDispatcher("/noPermission").forward(request, response);
            return false;
        }
        // =========场景3：合法访问，拥有权限，放行 =========
        return true;
    }
}
