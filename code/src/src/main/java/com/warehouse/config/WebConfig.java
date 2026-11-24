package com.warehouse.config;

import com.warehouse.util.AuthInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new AuthInterceptor())
                .addPathPatterns("/**")
                //放行：登录、无权限页面、静态资源、error
                .excludePathPatterns("/","/login","/noPermission","/css/**","/js/**","/error");
    }
}
