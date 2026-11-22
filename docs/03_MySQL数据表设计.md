# 仓库管理系统 MySQL 数据表设计（逻辑 + 物理设计）

| 项目 | 内容 |
| --- | --- |
| 课程名称 | 数据库系统课程设计 |
| 题目 | 仓库管理系统 |
| 阶段 | 阶段三：逻辑结构与物理结构设计（建表 SQL） |
| 数据库 | MySQL 8.0 |
| 文档说明 | 本文档可直接粘贴进课程设计报告第六章“逻辑设计”、第七章“物理设计” |

---

## 一、设计概述

### 1.1 技术规范

| 项目 | 选择 | 理由 |
| --- | --- | --- |
| 存储引擎 | InnoDB | 支持事务、行级锁与外键约束，满足退货、盘点等异常业务事务回滚需求 |
| 字符集 | utf8mb4 | 完整支持中文注释与数据 |
| 排序规则 | utf8mb4_general_ci | 大小写不敏感，便于查询 |
| 主键策略 | 自增整数 `表名_id` | 简单稳定，满足外键引用 |
| 金额/数量类型 | DECIMAL(12,2) | 避免浮点精度误差，保证成本核算与资金统计准确 |
| 状态字段 | TINYINT | 以 0/1/2 表示状态，节省空间且语义清晰 |

### 1.2 命名规范

1. 表名：`snake_case` 全小写，模块前缀（`sys_` 系统、`goods_` 货品、`inbound_`/`outbound_` 出入库、`transfer_` 调拨、`stocktake_` 盘点）。
2. 主键：`表名_id`（多对多中间表用 `id`）。
3. 外键：`关联表名_id`。
4. 唯一约束前缀 `uk_`、索引前缀 `idx_`、外键前缀 `fk_`、检查约束前缀 `chk_`。

### 1.3 表数量与分类

本设计共 **19 张表**，其中**业务表 11 张**（满足课程“业务实体表不少于 9 张”要求），辅助/基础资料表 8 张：

| 分类 | 数量 | 表名 |
| --- | --- | --- |
| 业务表（单据/台账/记录） | 11 | STOCK、STOCK_BATCH、INBOUND_ORDER、INBOUND_ITEM、OUTBOUND_ORDER、OUTBOUND_ITEM、TRANSFER_ORDER、TRANSFER_ITEM、STOCKTAKE_ORDER、STOCKTAKE_ITEM、STOCK_ALERT |
| 辅助/基础资料表（系统/主数据） | 8 | SYS_USER、SYS_ROLE、SYS_PERMISSION、SYS_ROLE_PERMISSION、GOODS_CATEGORY、SUPPLIER、WAREHOUSE、GOODS |

---

## 二、表结构总览

| 序号 | 表名 | 中文名 | 表类型 | 说明 |
| --- | --- | --- | --- | --- |
| 1 | sys_role | 角色表 | 辅助表 | 系统角色 |
| 2 | sys_permission | 权限表 | 辅助表 | 功能权限 |
| 3 | sys_role_permission | 角色权限中间表 | 辅助表 | 角色-权限多对多 |
| 4 | sys_user | 用户表 | 辅助表 | 系统操作人员 |
| 5 | goods_category | 货品分类表 | 辅助表 | 货品多级分类 |
| 6 | supplier | 供应商表 | 辅助表 | 供应商主数据 |
| 7 | warehouse | 仓库表 | 辅助表 | 仓库主数据 |
| 8 | goods | 货品基础信息表 | 辅助表 | 货品主数据（含上下限阈值、计价方式） |
| 9 | stock | 库存表 | 业务表 | 实时库存台账 |
| 10 | stock_batch | 成本批次表 | 业务表 | FIFO/LIFO 核算依据 |
| 11 | inbound_order | 入库单主表 | 业务表 | 采购入库/退货/回料/盘盈/调拨入 |
| 12 | inbound_item | 入库明细表 | 业务表 | 入库单明细 |
| 13 | outbound_order | 出库单主表 | 业务表 | 销售出库/领料/采购退货/盘亏/调拨出 |
| 14 | outbound_item | 出库明细表 | 业务表 | 出库单明细（含成本） |
| 15 | transfer_order | 调拨单主表 | 业务表 | 跨仓库调拨 |
| 16 | transfer_item | 调拨明细表 | 业务表 | 调拨明细 |
| 17 | stocktake_order | 盘点单主表 | 业务表 | 库存盘点 |
| 18 | stocktake_item | 盘点明细表 | 业务表 | 盘点账实比对 |
| 19 | stock_alert | 库存预警记录表 | 业务表 | 超储/短缺预警 |

---

## 三、完整建表 SQL（可直接执行）

```sql
-- ============================================================
-- 仓库管理系统数据库
-- MySQL 8.0 / InnoDB / utf8mb4
-- 说明：包含 19 张表（业务表 11 张 + 辅助表 8 张）
-- 执行方式：mysql -u root -p < 03_建表.sql
-- ============================================================

CREATE DATABASE IF NOT EXISTS warehouse_db DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE warehouse_db;

-- ------------------------------------------------------------
-- 删除旧表（按依赖关系反序，保证可重复执行）
-- ------------------------------------------------------------
DROP TABLE IF EXISTS stock_alert;
DROP TABLE IF EXISTS stocktake_item;
DROP TABLE IF EXISTS stocktake_order;
DROP TABLE IF EXISTS transfer_item;
DROP TABLE IF EXISTS transfer_order;
DROP TABLE IF EXISTS outbound_item;
DROP TABLE IF EXISTS outbound_order;
DROP TABLE IF EXISTS stock_batch;
DROP TABLE IF EXISTS inbound_item;
DROP TABLE IF EXISTS inbound_order;
DROP TABLE IF EXISTS stock;
DROP TABLE IF EXISTS goods;
DROP TABLE IF EXISTS warehouse;
DROP TABLE IF EXISTS supplier;
DROP TABLE IF EXISTS goods_category;
DROP TABLE IF EXISTS sys_user;
DROP TABLE IF EXISTS sys_role_permission;
DROP TABLE IF EXISTS sys_permission;
DROP TABLE IF EXISTS sys_role;

-- ------------------------------------------------------------
-- 1. 角色表（辅助表）
-- ------------------------------------------------------------
CREATE TABLE sys_role (
    role_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '角色编号',
    role_name VARCHAR(50) NOT NULL COMMENT '角色名称',
    role_code VARCHAR(50) NOT NULL COMMENT '角色编码',
    description VARCHAR(255) DEFAULT NULL COMMENT '角色描述',
    PRIMARY KEY (role_id),
    UNIQUE KEY uk_role_code (role_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色表';

-- ------------------------------------------------------------
-- 2. 权限表（辅助表）
-- ------------------------------------------------------------
CREATE TABLE sys_permission (
    permission_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '权限编号',
    permission_name VARCHAR(50) NOT NULL COMMENT '权限名称',
    permission_code VARCHAR(100) NOT NULL COMMENT '权限编码',
    description VARCHAR(255) DEFAULT NULL COMMENT '权限描述',
    PRIMARY KEY (permission_id),
    UNIQUE KEY uk_permission_code (permission_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='权限表';

-- ------------------------------------------------------------
-- 3. 角色权限中间表（辅助表，角色-权限多对多）
-- ------------------------------------------------------------
CREATE TABLE sys_role_permission (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
    role_id INT UNSIGNED NOT NULL COMMENT '角色编号',
    permission_id INT UNSIGNED NOT NULL COMMENT '权限编号',
    PRIMARY KEY (id),
    UNIQUE KEY uk_role_permission (role_id, permission_id),
    KEY idx_role_id (role_id),
    KEY idx_permission_id (permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES sys_role (role_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES sys_permission (permission_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='角色权限中间表';

-- ------------------------------------------------------------
-- 4. 用户表（辅助表）
-- ------------------------------------------------------------
CREATE TABLE sys_user (
    user_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户编号',
    username VARCHAR(50) NOT NULL COMMENT '登录账号',
    password VARCHAR(100) NOT NULL COMMENT '加密密码',
    real_name VARCHAR(50) NOT NULL COMMENT '真实姓名',
    role_id INT UNSIGNED NOT NULL COMMENT '所属角色编号',
    phone VARCHAR(20) DEFAULT NULL COMMENT '联系电话',
    email VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态(1启用 0禁用)',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_username (username),
    KEY idx_role_id (role_id),
    CONSTRAINT fk_user_role FOREIGN KEY (role_id) REFERENCES sys_role (role_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

-- ------------------------------------------------------------
-- 5. 货品分类表（辅助表，自关联实现多级分类）
-- ------------------------------------------------------------
CREATE TABLE goods_category (
    category_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类编号',
    category_name VARCHAR(50) NOT NULL COMMENT '分类名称',
    parent_id INT UNSIGNED DEFAULT NULL COMMENT '上级分类编号(自关联)',
    description VARCHAR(255) DEFAULT NULL COMMENT '分类描述',
    PRIMARY KEY (category_id),
    KEY idx_parent_id (parent_id),
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_id) REFERENCES goods_category (category_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='货品分类表';

-- ------------------------------------------------------------
-- 6. 供应商表（辅助表）
-- ------------------------------------------------------------
CREATE TABLE supplier (
    supplier_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '供应商编号',
    supplier_name VARCHAR(100) NOT NULL COMMENT '供应商名称',
    contact_name VARCHAR(50) DEFAULT NULL COMMENT '联系人',
    phone VARCHAR(20) DEFAULT NULL COMMENT '联系电话',
    address VARCHAR(255) DEFAULT NULL COMMENT '联系地址',
    email VARCHAR(100) DEFAULT NULL COMMENT '邮箱',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态(1启用 0禁用)',
    PRIMARY KEY (supplier_id),
    KEY idx_supplier_name (supplier_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='供应商表';

-- ------------------------------------------------------------
-- 7. 仓库表（辅助表）
-- ------------------------------------------------------------
CREATE TABLE warehouse (
    warehouse_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '仓库编号',
    warehouse_name VARCHAR(100) NOT NULL COMMENT '仓库名称',
    location VARCHAR(255) DEFAULT NULL COMMENT '仓库位置',
    manager VARCHAR(50) DEFAULT NULL COMMENT '负责人',
    phone VARCHAR(20) DEFAULT NULL COMMENT '联系电话',
    PRIMARY KEY (warehouse_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='仓库表';

-- ------------------------------------------------------------
-- 8. 货品基础信息表（辅助表，含库存上下限阈值与计价方式）
-- ------------------------------------------------------------
CREATE TABLE goods (
    goods_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '货品编号',
    goods_code VARCHAR(50) NOT NULL COMMENT '货品编码',
    goods_name VARCHAR(100) NOT NULL COMMENT '货品名称',
    spec VARCHAR(100) DEFAULT NULL COMMENT '规格型号',
    unit VARCHAR(20) NOT NULL DEFAULT '个' COMMENT '计量单位',
    category_id INT UNSIGNED NOT NULL COMMENT '所属分类编号',
    cost_method VARCHAR(10) NOT NULL DEFAULT 'FIFO' COMMENT '计价方式(FIFO/LIFO)',
    upper_limit DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '库存上限阈值',
    lower_limit DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '库存下限阈值',
    price DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '参考售价',
    status TINYINT NOT NULL DEFAULT 1 COMMENT '状态(1启用 0禁用)',
    PRIMARY KEY (goods_id),
    UNIQUE KEY uk_goods_code (goods_code),
    KEY idx_category_id (category_id),
    KEY idx_goods_name (goods_name),
    CONSTRAINT fk_goods_category FOREIGN KEY (category_id) REFERENCES goods_category (category_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_goods_limit CHECK (upper_limit >= lower_limit)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='货品基础信息表';

-- ------------------------------------------------------------
-- 9. 库存表（业务表，仓库+货品维度实时库存）
-- ------------------------------------------------------------
CREATE TABLE stock (
    stock_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '库存编号',
    warehouse_id INT UNSIGNED NOT NULL COMMENT '仓库编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    quantity DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '当前库存数量',
    total_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '库存占用资金',
    PRIMARY KEY (stock_id),
    UNIQUE KEY uk_warehouse_goods (warehouse_id, goods_id),
    KEY idx_goods_id (goods_id),
    KEY idx_warehouse_id (warehouse_id),
    CONSTRAINT fk_stock_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_stock_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_stock_quantity CHECK (quantity >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存表';

-- ------------------------------------------------------------
-- 10. 成本批次表（业务表，FIFO/LIFO 核算依据）
-- ------------------------------------------------------------
CREATE TABLE stock_batch (
    batch_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '批次编号',
    warehouse_id INT UNSIGNED NOT NULL COMMENT '仓库编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    inbound_item_id INT UNSIGNED NOT NULL COMMENT '来源入库明细编号',
    batch_no VARCHAR(50) NOT NULL COMMENT '批次号',
    quantity DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '批次剩余数量',
    unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '批次单位成本',
    inbound_date DATE NOT NULL COMMENT '入库日期',
    PRIMARY KEY (batch_id),
    UNIQUE KEY uk_inbound_item (inbound_item_id),
    KEY idx_batch_query (warehouse_id, goods_id, inbound_date),
    KEY idx_goods_id (goods_id),
    CONSTRAINT fk_batch_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_batch_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_batch_inbound_item FOREIGN KEY (inbound_item_id) REFERENCES inbound_item (item_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_batch_quantity CHECK (quantity >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成本批次表(FIFO/LIFO核算依据)';

-- ------------------------------------------------------------
-- 11. 入库单主表（业务表）
-- ------------------------------------------------------------
CREATE TABLE inbound_order (
    inbound_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '入库单编号',
    order_no VARCHAR(50) NOT NULL COMMENT '单据编号',
    biz_type VARCHAR(20) NOT NULL COMMENT '业务类型(采购入库/销售退货/回料/盘盈/调拨入)',
    warehouse_id INT UNSIGNED NOT NULL COMMENT '入库仓库编号',
    supplier_id INT UNSIGNED DEFAULT NULL COMMENT '供应商编号(采购入库)',
    operator_id INT UNSIGNED NOT NULL COMMENT '操作人编号',
    inbound_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '入库日期',
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '入库总金额',
    remark VARCHAR(255) DEFAULT NULL COMMENT '备注',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '单据状态(0待审核 1已审核 2作废)',
    PRIMARY KEY (inbound_id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_warehouse_id (warehouse_id),
    KEY idx_supplier_id (supplier_id),
    KEY idx_operator_id (operator_id),
    KEY idx_inbound_date (inbound_date),
    KEY idx_biz_type (biz_type),
    CONSTRAINT fk_ib_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ib_supplier FOREIGN KEY (supplier_id) REFERENCES supplier (supplier_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ib_operator FOREIGN KEY (operator_id) REFERENCES sys_user (user_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='入库单主表';

-- ------------------------------------------------------------
-- 12. 入库明细表（业务表）
-- ------------------------------------------------------------
CREATE TABLE inbound_item (
    item_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '明细编号',
    inbound_id INT UNSIGNED NOT NULL COMMENT '入库单编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    quantity DECIMAL(12,2) NOT NULL COMMENT '入库数量',
    unit_price DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '入库单价',
    amount DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '金额',
    PRIMARY KEY (item_id),
    KEY idx_inbound_id (inbound_id),
    KEY idx_goods_id (goods_id),
    CONSTRAINT fk_ibi_order FOREIGN KEY (inbound_id) REFERENCES inbound_order (inbound_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ibi_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='入库明细表';

-- ------------------------------------------------------------
-- 13. 出库单主表（业务表）
-- ------------------------------------------------------------
CREATE TABLE outbound_order (
    outbound_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '出库单编号',
    order_no VARCHAR(50) NOT NULL COMMENT '单据编号',
    biz_type VARCHAR(20) NOT NULL COMMENT '业务类型(销售出库/领料/采购退货/盘亏/调拨出)',
    warehouse_id INT UNSIGNED NOT NULL COMMENT '出库仓库编号',
    operator_id INT UNSIGNED NOT NULL COMMENT '操作人编号',
    outbound_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '出库日期',
    total_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '出库总成本',
    total_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '出库总金额',
    remark VARCHAR(255) DEFAULT NULL COMMENT '备注',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '单据状态(0待审核 1已审核 2作废)',
    PRIMARY KEY (outbound_id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_warehouse_id (warehouse_id),
    KEY idx_operator_id (operator_id),
    KEY idx_outbound_date (outbound_date),
    KEY idx_biz_type (biz_type),
    CONSTRAINT fk_ob_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ob_operator FOREIGN KEY (operator_id) REFERENCES sys_user (user_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='出库单主表';

-- ------------------------------------------------------------
-- 14. 出库明细表（业务表，含 FIFO/LIFO 计算结果）
-- ------------------------------------------------------------
CREATE TABLE outbound_item (
    item_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '明细编号',
    outbound_id INT UNSIGNED NOT NULL COMMENT '出库单编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    quantity DECIMAL(12,2) NOT NULL COMMENT '出库数量',
    unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '单位成本(FIFO/LIFO计算)',
    total_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '成本金额',
    PRIMARY KEY (item_id),
    KEY idx_outbound_id (outbound_id),
    KEY idx_goods_id (goods_id),
    CONSTRAINT fk_obi_order FOREIGN KEY (outbound_id) REFERENCES outbound_order (outbound_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_obi_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='出库明细表';

-- ------------------------------------------------------------
-- 15. 调拨单主表（业务表）
-- ------------------------------------------------------------
CREATE TABLE transfer_order (
    transfer_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '调拨单编号',
    order_no VARCHAR(50) NOT NULL COMMENT '单据编号',
    from_warehouse_id INT UNSIGNED NOT NULL COMMENT '调出仓库编号',
    to_warehouse_id INT UNSIGNED NOT NULL COMMENT '调入仓库编号',
    operator_id INT UNSIGNED NOT NULL COMMENT '操作人编号',
    transfer_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '调拨日期',
    remark VARCHAR(255) DEFAULT NULL COMMENT '备注',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '单据状态(0待审核 1已审核 2作废)',
    PRIMARY KEY (transfer_id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_from_warehouse (from_warehouse_id),
    KEY idx_to_warehouse (to_warehouse_id),
    KEY idx_operator_id (operator_id),
    CONSTRAINT fk_tf_from FOREIGN KEY (from_warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tf_to FOREIGN KEY (to_warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_tf_operator FOREIGN KEY (operator_id) REFERENCES sys_user (user_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='调拨单主表';

-- ------------------------------------------------------------
-- 16. 调拨明细表（业务表）
-- ------------------------------------------------------------
CREATE TABLE transfer_item (
    item_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '明细编号',
    transfer_id INT UNSIGNED NOT NULL COMMENT '调拨单编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    quantity DECIMAL(12,2) NOT NULL COMMENT '调拨数量',
    PRIMARY KEY (item_id),
    KEY idx_transfer_id (transfer_id),
    KEY idx_goods_id (goods_id),
    CONSTRAINT fk_ti_order FOREIGN KEY (transfer_id) REFERENCES transfer_order (transfer_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ti_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='调拨明细表';

-- ------------------------------------------------------------
-- 17. 盘点单主表（业务表）
-- ------------------------------------------------------------
CREATE TABLE stocktake_order (
    stocktake_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '盘点单编号',
    order_no VARCHAR(50) NOT NULL COMMENT '单据编号',
    warehouse_id INT UNSIGNED NOT NULL COMMENT '盘点仓库编号',
    operator_id INT UNSIGNED NOT NULL COMMENT '操作人编号',
    stocktake_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '盘点日期',
    remark VARCHAR(255) DEFAULT NULL COMMENT '备注',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '单据状态(0待审核 1已审核 2作废)',
    PRIMARY KEY (stocktake_id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_warehouse_id (warehouse_id),
    KEY idx_operator_id (operator_id),
    CONSTRAINT fk_st_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_st_operator FOREIGN KEY (operator_id) REFERENCES sys_user (user_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='盘点单主表';

-- ------------------------------------------------------------
-- 18. 盘点明细表（业务表）
-- ------------------------------------------------------------
CREATE TABLE stocktake_item (
    item_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '明细编号',
    stocktake_id INT UNSIGNED NOT NULL COMMENT '盘点单编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    book_quantity DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '账面数量',
    actual_quantity DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '实盘数量',
    diff_quantity DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '差异数量',
    diff_type VARCHAR(10) DEFAULT 'NONE' COMMENT '差异类型(GAIN盘盈/LOSS盘亏/NONE无差异)',
    PRIMARY KEY (item_id),
    KEY idx_stocktake_id (stocktake_id),
    KEY idx_goods_id (goods_id),
    CONSTRAINT fk_sti_order FOREIGN KEY (stocktake_id) REFERENCES stocktake_order (stocktake_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_sti_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='盘点明细表';

-- ------------------------------------------------------------
-- 19. 库存预警记录表（业务表，由触发器自动写入）
-- ------------------------------------------------------------
CREATE TABLE stock_alert (
    alert_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '预警编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    warehouse_id INT UNSIGNED NOT NULL COMMENT '仓库编号',
    alert_type VARCHAR(10) NOT NULL COMMENT '预警类型(OVER超储/LOW短缺)',
    current_quantity DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '当前库存数量',
    threshold DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '触发阈值',
    alert_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '预警时间',
    status TINYINT NOT NULL DEFAULT 0 COMMENT '处理状态(0未处理 1已处理)',
    PRIMARY KEY (alert_id),
    KEY idx_goods_id (goods_id),
    KEY idx_warehouse_id (warehouse_id),
    KEY idx_status (status),
    CONSTRAINT fk_sa_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_sa_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存预警记录表';
```

---

## 四、字段说明

### 4.1 字段命名与类型规范

| 字段类别 | 命名规则 | 数据类型 | 示例 |
| --- | --- | --- | --- |
| 主键 | `表名_id` | INT UNSIGNED AUTO_INCREMENT | goods_id |
| 外键 | `关联表名_id` | INT UNSIGNED | category_id |
| 编码类 | `xxx_code` | VARCHAR(50) | goods_code |
| 名称类 | `xxx_name` | VARCHAR(50~100) | goods_name |
| 金额类 | `xxx_amount` / `xxx_cost` / `xxx_price` | DECIMAL(12,2) | total_amount |
| 数量类 | `quantity` / `xxx_quantity` | DECIMAL(12,2) | quantity |
| 状态类 | `status` | TINYINT | status |
| 时间类 | `xxx_date` / `xxx_time` / `created_at` | DATETIME / DATE | inbound_date |
| 备注类 | `remark` / `description` | VARCHAR(255) | remark |

### 4.2 关键业务字段说明

| 字段 | 所在表 | 作用 |
| --- | --- | --- |
| cost_method | goods | 标记货品计价方式（FIFO/LIFO），成本核算时据此决定批次扣减顺序 |
| upper_limit / lower_limit | goods | 库存上/下限阈值，供预警触发器判断 |
| quantity / total_cost | stock | 实时库存数量与库存占用资金 |
| quantity / unit_cost / inbound_date | stock_batch | 成本批次剩余数量、单位成本、入库日期，FIFO/LIFO 扣减依据 |
| biz_type | inbound_order / outbound_order | 单据业务类型，统一承载采购、销售、退货、领料、回料、盘点、调拨 |
| unit_cost / total_cost | outbound_item | 出库成本计算结果 |
| diff_quantity / diff_type | stocktake_item | 盘点差异数量与盘盈盘亏类型 |
| alert_type | stock_alert | 预警类型（超储/短缺） |

---

## 五、表关系说明

### 5.1 外键关系总表

| 外键 | 所属表 | 引用表 | 引用动作 | 说明 |
| --- | --- | --- | --- | --- |
| fk_user_role | sys_user | sys_role | RESTRICT | 用户属于一个角色 |
| fk_rp_role / fk_rp_permission | sys_role_permission | sys_role / sys_permission | CASCADE | 角色-权限多对多 |
| fk_category_parent | goods_category | goods_category | SET NULL | 分类自关联（上级分类） |
| fk_goods_category | goods | goods_category | RESTRICT | 货品属于一个分类 |
| fk_stock_warehouse / fk_stock_goods | stock | warehouse / goods | RESTRICT | 库存属于仓库与货品 |
| fk_batch_* | stock_batch | warehouse / goods / inbound_item | RESTRICT | 批次关联来源入库明细 |
| fk_ib_warehouse / fk_ib_supplier / fk_ib_operator | inbound_order | warehouse / supplier / sys_user | RESTRICT | 入库单关联仓库、供应商、操作人 |
| fk_ibi_order / fk_ibi_goods | inbound_item | inbound_order / goods | CASCADE / RESTRICT | 入库明细 |
| fk_ob_warehouse / fk_ob_operator | outbound_order | warehouse / sys_user | RESTRICT | 出库单关联仓库、操作人 |
| fk_obi_order / fk_obi_goods | outbound_item | outbound_order / goods | CASCADE / RESTRICT | 出库明细 |
| fk_tf_from / fk_tf_to | transfer_order | warehouse | RESTRICT | 调拨调出/调入仓库 |
| fk_ti_order / fk_ti_goods | transfer_item | transfer_order / goods | CASCADE / RESTRICT | 调拨明细 |
| fk_st_warehouse / fk_st_operator | stocktake_order | warehouse / sys_user | RESTRICT | 盘点单 |
| fk_sti_order / fk_sti_goods | stocktake_item | stocktake_order / goods | CASCADE / RESTRICT | 盘点明细 |
| fk_sa_goods / fk_sa_warehouse | stock_alert | goods / warehouse | RESTRICT | 预警记录 |

### 5.2 引用动作说明

1. **RESTRICT（限制删除）**：被引用记录存在时禁止删除父记录，防止删除仓库/货品/供应商导致业务数据悬挂。
2. **CASCADE（级联）**：主表单据删除时级联删除明细表，以及角色/权限删除时级联删除映射关系。
3. **SET NULL（置空）**：删除上级分类时子分类的 `parent_id` 置空。
4. **ON UPDATE CASCADE**：主键变更时同步更新外键，保持引用一致性。

---

## 六、FIFO/LIFO 出库成本核算字段支撑说明

### 6.1 支撑字段

| 字段 | 作用 |
| --- | --- |
| goods.cost_method | 标识该货品采用 FIFO 还是 LIFO |
| stock_batch.unit_cost | 每批入库的单位成本 |
| stock_batch.quantity | 每批剩余可出库数量 |
| stock_batch.inbound_date | 批次先后顺序依据 |
| stock_batch.warehouse_id + goods_id | 定位到“某仓库某货品”的批次集合 |
| outbound_item.unit_cost / total_cost | 保存计算得出的出库成本 |

### 6.2 计算过程

1. 出库时根据货品 `cost_method` 选择批次扣减顺序：FIFO 按 `inbound_date ASC`（先进先出），LIFO 按 `inbound_date DESC`（后进先出）。
2. 依次扣减批次 `stock_batch.quantity`，直至本次出库数量扣完。
3. 汇总各批次被扣减部分成本：`出库总成本 = Σ(扣减数量 × unit_cost)`。
4. 将结果写入 `outbound_item.unit_cost` 与 `outbound_order.total_cost`，并更新各批次剩余数量。
5. 上述逻辑由出库存储过程实现（阶段四落地），本设计在 ER/表结构层已提供完整字段支撑。

---

## 七、约束与索引设计汇总

### 7.1 完整性约束

| 约束类型 | 数量 | 说明 |
| --- | --- | --- |
| 主键 PRIMARY KEY | 19 | 每表一个自增主键 |
| 外键 FOREIGN KEY | 约 30 | 保证引用完整性 |
| 唯一 UNIQUE | 约 9 | 账号、编码、单据号、仓库货品维度唯一 |
| 非空 NOT NULL | 大量 | 关键字段不允许为空 |
| 检查 CHECK | 3 | 数量非负、上限不小于下限 |

### 7.2 业务索引

| 索引 | 所在表 | 用途 |
| --- | --- | --- |
| idx_category_id | goods | 按分类查询货品 |
| idx_goods_name | goods | 按名称模糊查询 |
| uk_warehouse_goods / idx_goods_id | stock | 库存定位与货品维度查询 |
| idx_batch_query(warehouse_id, goods_id, inbound_date) | stock_batch | FIFO/LIFO 批次扣减查询 |
| idx_warehouse_id / idx_supplier_id / idx_inbound_date / idx_biz_type | inbound_order | 入库单据多维查询 |
| idx_warehouse_id / idx_outbound_date / idx_biz_type | outbound_order | 出库单据多维查询 |
| idx_from_warehouse / idx_to_warehouse | transfer_order | 调拨仓库查询 |
| idx_warehouse_id | stocktake_order | 盘点单查询 |
| idx_goods_id / idx_warehouse_id / idx_status | stock_alert | 预警查询与处理 |

---

## 八、执行说明

1. 本文档第三章节的 SQL 为完整可执行脚本，包含建库、建表、约束、索引。
2. 执行方式（任选其一）：
   - MySQL 命令行：`mysql -u root -p < 03_建表.sql`
   - 图形工具（Navicat / MySQL Workbench）：直接粘贴运行。
3. CHECK 约束需 MySQL 8.0.16 及以上版本才会强制执行，较低 8.0 版本仍可正常建表（仅不校验）。
4. 建表完成后，可通过 `SHOW TABLES;` 验证 19 张表是否全部创建成功。
