# 仓库管理系统

基于 Spring Boot、MyBatis、Thymeleaf 与 MySQL 8.0 的仓储管理课程项目，覆盖采购入库、销售/领料出库、库存盘点、仓库调拨、库存预警与统计查询。

## 目录结构

```text
code/
  sql/       数据库建表、视图、触发器、存储过程与验证脚本
  src/       Spring Boot 工程
docs/        需求、设计、实现和演示文档
报告/        课程报告与答辩材料
```

## 本地运行

前置条件：JDK 17、Maven 3.9+、MySQL 8.0。

1. 复制 `code/src/.env.example` 为 `code/src/.env`，填入本机 MySQL 密码。真实 `.env` 已被 Git 忽略，不能提交。
2. 按顺序执行 `code/sql/01_create_tables.sql` 至 `code/sql/05_test_and_verify.sql`。
3. 在 `code/src` 目录运行：

   ```powershell
   mvn spring-boot:run
   ```

4. 打开 `http://localhost:8080`，使用演示账号 `user01 / 123456` 登录。

## 验证构建

```powershell
cd code/src
mvn test
```

> `application.yml` 会自动读取当前工作目录中的 `.env`。请勿将真实密码、IDE 配置、构建产物或本地备份上传到版本库。
