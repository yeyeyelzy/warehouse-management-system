-- ============================================================
-- 仓库管理系统数据库
-- MySQL 8.0 / InnoDB / utf8mb4
-- 说明：包含 19 张表（业务表 11 张 + 辅助表 8 张）
-- 执行方式：mysql -u root -p < 01_create_tables.sql
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
-- 10. 入库单主表（业务表）
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
-- 11. 入库明细表（业务表）
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
    CONSTRAINT fk_ibi_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_inbound_price CHECK (unit_price >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='入库明细表';

-- ------------------------------------------------------------
-- 12. 出库单主表（业务表）
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
-- 13. 出库明细表（业务表，含 FIFO/LIFO 计算结果）
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
-- 14. 调拨单主表（业务表）
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
-- 15. 调拨明细表（业务表）
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
-- 16. 盘点单主表（业务表）
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
-- 17. 盘点明细表（业务表）
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
-- 18. 成本批次表（业务表，FIFO/LIFO 核算依据）
-- ------------------------------------------------------------
CREATE TABLE stock_batch (
    batch_id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '批次编号',
    warehouse_id INT UNSIGNED NOT NULL COMMENT '仓库编号',
    goods_id INT UNSIGNED NOT NULL COMMENT '货品编号',
    inbound_item_id INT UNSIGNED NULL COMMENT '来源入库明细编号，盘盈新增批次为空',
    batch_no VARCHAR(50) NOT NULL COMMENT '批次号',
    quantity DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '批次剩余数量',
    unit_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT '批次单位成本',
    remaining_cost DECIMAL(12,2) NOT NULL COMMENT '批次剩余成本金额',
    inbound_date DATE NOT NULL COMMENT '入库日期',
    PRIMARY KEY (batch_id),
    KEY idx_batch_inbound_item (inbound_item_id),
    KEY idx_batch_query (warehouse_id, goods_id, inbound_date),
    KEY idx_goods_id (goods_id),
    CONSTRAINT fk_batch_warehouse FOREIGN KEY (warehouse_id) REFERENCES warehouse (warehouse_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_batch_goods FOREIGN KEY (goods_id) REFERENCES goods (goods_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_batch_inbound_item FOREIGN KEY (inbound_item_id) REFERENCES inbound_item (item_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_batch_quantity CHECK (quantity >= 0),
    CONSTRAINT chk_batch_cost CHECK (remaining_cost >= 0 AND (quantity > 0 OR remaining_cost = 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='成本批次表(FIFO/LIFO核算依据)';
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
