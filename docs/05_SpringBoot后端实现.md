# 仓库管理系统 Java 后端实现说明

| 项目 | 内容 |
| --- | --- |
| 课程名称 | 数据库系统课程设计 |
| 题目 | 仓库管理系统 |
| 阶段 | 阶段五：Java 后端实现（Spring Boot + MyBatis + Thymeleaf） |
| 技术栈 | Java 8 + Spring Boot 2.7 + MyBatis + MySQL 8.0 + Thymeleaf |

---

## 一、技术架构与设计理念

本系统采用 **Spring Boot + MyBatis + Thymeleaf + MySQL 8.0** 技术栈，采用标准分层架构：

```
src/
├── pom.xml
└── src/main/
    ├── java/com/warehouse/
    │   ├── WarehouseApplication.java      # 启动类
    │   ├── config/WebConfig.java          # MVC 配置（拦截器注册）
    │   ├── controller/                    # 控制层
    │   │   ├── LoginController.java
    │   │   ├── GoodsController.java
    │   │   ├── BusinessController.java
    │   │   ├── StockController.java
    │   │   └── DeepSeekController.java    # 预留 AI 接口
    │   ├── entity/                        # 实体层
    │   │   ├── Goods.java / Warehouse.java / Supplier.java
    │   │   ├── StockView.java / StockAlert.java / SysUser.java
    │   ├── mapper/                        # DAO 层
    │   │   ├── GoodsMapper.java / WarehouseMapper.java / SupplierMapper.java
    │   │   ├── SysUserMapper.java / StockMapper.java
    │   │   └── ProcedureMapper.java       # 存储过程调用
    │   ├── service/                       # 业务层
    │   │   ├── AuthService.java / GoodsService.java
    │   │   ├── BusinessService.java / StockService.java
    │   └── util/                          # 工具
    │       ├── BusinessException.java / ProcedureResult.java
    │       ├── AuthInterceptor.java / DeepSeekClient.java
    └── resources/
        ├── application.yml
        ├── static/css/style.css
        └── templates/                     # Thymeleaf 页面
            ├── fragments.html / login.html / home.html
            ├── goods.html / inbound.html / outbound.html
            ├── materialIssue.html / materialReturn.html
            ├── return.html / stocktake.html / transfer.html
            └── stock.html / warning.html / report.html
```

### 设计理念（突出数据库课程设计重点）

1. **核心业务逻辑下沉 MySQL**：入库、出库成本核算（FIFO/LIFO）、盘点、调拨的业务主体在数据库侧，由存储过程实现（含事务、异常回滚）；Java 层只做参数校验、业务组装、调用存储过程、读取状态码与消息，**不把成本算法写在 Java 代码里**。
2. **充分利用触发器自动联动库存**：入库明细插入由触发器 `trg_inbound_item_after_insert` 自动累加库存、出库审核通过由触发器 `trg_outbound_order_after_approve` 自动扣减库存、库存变动由触发器 `trg_stock_after_insert/update` 自动生成预警记录，**Java 代码不重复编写库存更新逻辑**。
3. **查询封装为视图**：库存总览、预警货品等查询基于 MySQL 视图，Java Mapper 直接查询视图，降低代码复杂度。

---

## 二、分层职责说明

| 层 | 职责 |
| --- | --- |
| entity | 实体类，与表/视图字段一一对应 |
| mapper（DAO） | 数据访问；`ProcedureMapper` 通过 MyBatis CALLABLE 语句调用 4 个存储过程 |
| service | 参数校验、业务组装；`BusinessService` 调用存储过程并读取 OUT 状态 |
| controller | 接收请求、跳转 Thymeleaf 页面、返回结果 |
| util | 业务异常、存储过程结果封装、登录拦截器、DeepSeek 预留客户端 |

---

## 三、关键实现

### 3.1 存储过程调用（Mapper 层）

`ProcedureMapper` 使用 MyBatis 的 `statementType = CALLABLE` 调用 MySQL 存储过程，OUT 参数执行后写回 `Map`：

```java
@Select("{CALL sp_outbound_cost(#{warehouseId,mode=IN,jdbcType=INTEGER}, ..., #{statusCode,mode=OUT,jdbcType=INTEGER}, #{statusMsg,mode=OUT,jdbcType=VARCHAR}, #{outTotalCost,mode=OUT,jdbcType=DECIMAL})}")
@Options(statementType = StatementType.CALLABLE)
void callOutboundCost(Map<String, Object> params);
```

### 3.2 事务与异常回滚

存储过程内部已实现 `START TRANSACTION / COMMIT / ROLLBACK`，并声明 `EXIT HANDLER FOR SQLEXCEPTION` 捕获异常后回滚。Java 侧在 `BusinessService.checkResult` 中读取 OUT 状态码：状态码非 0 时抛出 `BusinessException`，由 Controller 捕获并提示用户，**数据库事务回滚已在存储过程内完成**，保证账实一致。

### 3.3 参数校验与业务组装（Service 层）

`BusinessService` 对每个业务方法做参数组装，并调用对应存储过程；`GoodsService` 对货品保存做字段校验（名称非空、计价方式仅 FIFO/LIFO）。

### 3.4 极简易用美观的页面（Thymeleaf）

- 使用 Thymeleaf 模板引擎 + 一套简洁 CSS，通过 `fragments.html` 复用头部导航；
- 页面仅用基础表格、表单，无复杂动画，样式整洁、操作直观；
- 所有表单操作均有成功/失败提示（`flash` 消息），库存预警页面用红/黄标签区分 LOW/OVER。

---

## 四、页面清单（12 个业务页面，无借还模块入口）

| 页面 | 路径 | 底层对象 |
| --- | --- | --- |
| 登录主页 | /login、/home | sys_user 表 |
| 货品管理 | /goods | goods 表 CRUD |
| 采购入库 | /biz/inbound | 存储过程 sp_inbound + 触发器累加库存 |
| 销售出库 | /biz/outbound | 存储过程 sp_outbound_cost（FIFO/LIFO） |
| 领料出库 | /biz/materialIssue | sp_outbound_cost（biz_type=MATERIAL_ISSUE） |
| 回料入库 | /biz/materialReturn | sp_inbound（biz_type=MATERIAL_RETURN） |
| 退货处理 | /biz/return | sp_outbound_cost(PURCHASE_RETURN) / sp_inbound(SALE_RETURN) |
| 库存盘点 | /biz/stocktake | sp_stocktake |
| 仓库调拨 | /biz/transfer | sp_transfer（JSON 批量明细） |
| 库存查询 | /stock | 视图 v_stock_overview |
| 库存预警查看 | /warning | 视图 v_stock_warning + 表 stock_alert |
| 统计报表 | /report | 出入库汇总、供应商供货、盘点盈亏 3 组统计 |

> 领料、回料、退货页面复用系统通用出入库存储过程，通过 `biz_type` 字段区分业务类型，不额外开发独立存储流程。本系统不实现物品借还功能，页面无借还模块入口。

---

## 五、运行说明

1. 先依次执行 `code/sql/01~05` 脚本完成建表、视图、触发器、存储过程、测试数据。
2. 复制 `code/src/.env.example` 为 `code/src/.env`，填写本机数据库密码；真实 `.env` 不提交到版本库。
3. 在 `code/src/` 目录执行 `mvn spring-boot:run`（或 IDE 启动 `WarehouseApplication`）。
4. 浏览器访问 `http://localhost:8080`，使用演示账号 `user01 / 123456`（测试数据用户名 user01~user30，密码均为 123456）登录。

---

## 六、第二次答辩可演示业务清单

| 序号 | 业务 | 演示要点 |
| --- | --- | --- |
| 1 | 采购入库 | 入库后库存自动累加（触发器） |
| 2 | 销售出库 | FIFO / LIFO 两种成本核算（存储过程），出库成本直观展示 |
| 3 | 领料出库 | biz_type=MATERIAL_ISSUE 复用出库过程 |
| 4 | 回料入库 | biz_type=MATERIAL_RETURN 复用入库过程 |
| 5 | 退货处理 | 采购退货/销售退货异常业务 |
| 6 | 库存盘点 | 盘盈盘亏自动生成盘点记录并修正库存 |
| 7 | 仓库调拨 | 跨仓库转移，事务整体回滚 |
| 8 | 库存查询 | 视图实时库存总览 |
| 9 | 库存预警 | 触发器自动生成预警记录 |
| 10 | 统计报表 | 出入库汇总、供应商供货、盘点盈亏 3 组统计 |
