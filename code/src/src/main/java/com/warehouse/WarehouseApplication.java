package com.warehouse;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 仓库管理系统启动类
 * 技术栈：Spring Boot + MyBatis + MySQL 8.0 + Thymeleaf
 * 核心业务逻辑下沉到 MySQL（存储过程/触发器/视图）
 */
@SpringBootApplication
@MapperScan("com.warehouse.mapper")
public class WarehouseApplication {
    public static void main(String[] args) {
        SpringApplication.run(WarehouseApplication.class, args);
    }
}
