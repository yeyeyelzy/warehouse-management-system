-- A：角色、权限与演示账号初始化。请在 01~05 脚本之后执行。
USE warehouse_db;
START TRANSACTION;
INSERT INTO sys_role (role_id, role_name, role_code) VALUES
(1,'系统管理员','ROLE_01'), (2,'仓库管理员','ROLE_02'),
(3,'采购人员','ROLE_03'), (4,'领料人员','ROLE_04')
ON DUPLICATE KEY UPDATE role_name = VALUES(role_name);
INSERT INTO sys_permission (permission_name, permission_code) VALUES
('货品管理','goods:manage'),
('采购入库','biz:inbound'),
('销售出库','biz:outbound'),
('领料出库','biz:apply'),
('回料入库','biz:materialReturn'),
('退货处理','biz:purchaseReturn'),
('库存盘点','biz:check'),
('仓库调拨','biz:transfer'),
('库存查询','stock:view'),
('库存预警','biz:warning'),
('统计报表','report:view'),
('用户管理','user:manage'),
('角色权限分配','role:assign')
ON DUPLICATE KEY UPDATE permission_name = VALUES(permission_name);
DELETE FROM sys_role_permission WHERE role_id IN (1,2,3,4);
INSERT INTO sys_role_permission (role_id, permission_id)
SELECT r.role_id, p.permission_id FROM sys_role r CROSS JOIN sys_permission p
WHERE (r.role_id = 1 AND p.permission_code IN ('goods:manage', 'biz:inbound', 'biz:outbound', 'biz:apply', 'biz:materialReturn', 'biz:purchaseReturn', 'biz:check', 'biz:transfer', 'stock:view', 'biz:warning', 'report:view', 'user:manage', 'role:assign'))
   OR (r.role_id = 2 AND p.permission_code IN ('goods:manage', 'biz:inbound', 'biz:outbound', 'biz:apply', 'biz:materialReturn', 'biz:purchaseReturn', 'biz:check', 'biz:transfer', 'stock:view', 'biz:warning', 'report:view'))
   OR (r.role_id = 3 AND p.permission_code IN ('biz:inbound','biz:purchaseReturn','stock:view'))
   OR (r.role_id = 4 AND p.permission_code IN ('biz:apply','biz:materialReturn','stock:view'));
INSERT INTO sys_user (username,password,real_name,role_id,status)
VALUES ('lab_admin',CONCAT('000000000000000000000000000000a1:', SHA2(CONCAT('000000000000000000000000000000a1','123456'),256)),'实验系统管理员',1,1),
       ('lab_keeper',CONCAT('000000000000000000000000000000a2:', SHA2(CONCAT('000000000000000000000000000000a2','123456'),256)),'实验仓库管理员',2,1),
       ('lab_buyer',CONCAT('000000000000000000000000000000a3:', SHA2(CONCAT('000000000000000000000000000000a3','123456'),256)),'实验采购人员',3,1),
       ('lab_requester',CONCAT('000000000000000000000000000000a4:', SHA2(CONCAT('000000000000000000000000000000a4','123456'),256)),'实验领料人员',4,1)
ON DUPLICATE KEY UPDATE password = VALUES(password), real_name = VALUES(real_name), role_id = VALUES(role_id), status = VALUES(status);
COMMIT;
