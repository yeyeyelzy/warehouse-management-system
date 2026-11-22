# -*- coding: utf-8 -*-
"""生成《仓库管理系统课程设计报告.pdf》扩充版（按宾馆系统报告模板结构）"""
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                                TableStyle, PageBreak)
from reportlab.platypus.tableofcontents import TableOfContents

pdfmetrics.registerFont(UnicodeCIDFont('STSong-Light'))
F = 'STSong-Light'

st_title = ParagraphStyle('title', fontName=F, fontSize=26, alignment=TA_CENTER, leading=34, spaceAfter=8)
st_sub = ParagraphStyle('sub', fontName=F, fontSize=18, alignment=TA_CENTER, leading=28, spaceAfter=40)
st_ci = ParagraphStyle('ci', fontName=F, fontSize=15, alignment=TA_CENTER, leading=34)
st_toc = ParagraphStyle('tochead', fontName=F, fontSize=18, alignment=TA_CENTER, leading=28, spaceAfter=18)
st_h1 = ParagraphStyle('H1', fontName=F, fontSize=15, leading=22, spaceBefore=16, spaceAfter=8)
st_h2 = ParagraphStyle('H2', fontName=F, fontSize=13, leading=20, spaceBefore=12, spaceAfter=6)
st_h3 = ParagraphStyle('H3', fontName=F, fontSize=12, leading=18, spaceBefore=10, spaceAfter=4)
st_body = ParagraphStyle('body', fontName=F, fontSize=11, leading=18, firstLineIndent=22, alignment=TA_JUSTIFY, spaceAfter=4)
st_bn = ParagraphStyle('bn', parent=st_body, firstLineIndent=0)
st_cell = ParagraphStyle('cell', fontName=F, fontSize=9, leading=13, alignment=TA_LEFT)
st_ph = ParagraphStyle('ph', fontName=F, fontSize=12, alignment=TA_CENTER, leading=20, spaceBefore=10, spaceAfter=10,
                       textColor=colors.HexColor('#c0392b'))

def H1(t): return Paragraph(t, st_h1)
def H2(t): return Paragraph(t, st_h2)
def H3(t): return Paragraph(t, st_h3)
def P(t): return Paragraph(t, st_body)
def PN(t): return Paragraph(t, st_bn)
def PH(t): return Paragraph(t, st_ph)
def cell(t): return Paragraph(str(t), st_cell)

GRID = TableStyle([('GRID',(0,0),(-1,-1),0.5,colors.grey),
                   ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#eef2fb')),
                   ('VALIGN',(0,0),(-1,-1),'MIDDLE'),
                   ('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),
                   ('TOPPADDING',(0,0),(-1,-1),3),('BOTTOMPADDING',(0,0),(-1,-1),3)])

def table(headers, rows, widths):
    data = [[cell(h) for h in headers]] + [[cell(c) for c in r] for r in rows]
    t = Table(data, colWidths=widths)
    t.setStyle(GRID)
    return t

def on_first(canvas, doc): pass
def on_later(canvas, doc):
    canvas.saveState()
    canvas.setFont(F, 9)
    canvas.drawCentredString(A4[0]/2, 1.4*cm, str(doc.page))
    canvas.restoreState()

class ReportDoc(SimpleDocTemplate):
    def afterFlowable(self, flowable):
        if isinstance(flowable, Paragraph):
            n = flowable.style.name
            if n in ('H1','H2','H3'):
                self.notify('TOCEntry', ({'H1':0,'H2':1,'H3':2}[n], flowable.getPlainText(), self.page))

# ================= 19 张表字段字典 =================
TABLES = [
    ('sys_user','用户表',[('user_id','INT','PK','用户编号'),('username','VARCHAR(50)','UK','登录账号'),('password','VARCHAR(100)','','加密密码'),('real_name','VARCHAR(50)','','真实姓名'),('role_id','INT','FK','所属角色'),('phone','VARCHAR(20)','','联系电话'),('email','VARCHAR(100)','','邮箱'),('status','TINYINT','','状态(1启用0禁用)'),('created_at','DATETIME','','创建时间')]),
    ('sys_role','角色表',[('role_id','INT','PK','角色编号'),('role_name','VARCHAR(50)','','角色名称'),('role_code','VARCHAR(50)','UK','角色编码'),('description','VARCHAR(255)','','角色描述')]),
    ('sys_permission','权限表',[('permission_id','INT','PK','权限编号'),('permission_name','VARCHAR(50)','','权限名称'),('permission_code','VARCHAR(100)','UK','权限编码'),('description','VARCHAR(255)','','权限描述')]),
    ('sys_role_permission','角色权限中间表',[('id','INT','PK','主键'),('role_id','INT','FK','角色编号'),('permission_id','INT','FK','权限编号')]),
    ('goods_category','货品分类表',[('category_id','INT','PK','分类编号'),('category_name','VARCHAR(50)','','分类名称'),('parent_id','INT','FK','上级分类编号(自关联)'),('description','VARCHAR(255)','','分类描述')]),
    ('supplier','供应商表',[('supplier_id','INT','PK','供应商编号'),('supplier_name','VARCHAR(100)','','供应商名称'),('contact_name','VARCHAR(50)','','联系人'),('phone','VARCHAR(20)','','联系电话'),('address','VARCHAR(255)','','联系地址'),('email','VARCHAR(100)','','邮箱'),('status','TINYINT','','状态')]),
    ('warehouse','仓库表',[('warehouse_id','INT','PK','仓库编号'),('warehouse_name','VARCHAR(100)','','仓库名称'),('location','VARCHAR(255)','','仓库位置'),('manager','VARCHAR(50)','','负责人'),('phone','VARCHAR(20)','','联系电话')]),
    ('goods','货品基础信息表',[('goods_id','INT','PK','货品编号'),('goods_code','VARCHAR(50)','UK','货品编码'),('goods_name','VARCHAR(100)','','货品名称'),('spec','VARCHAR(100)','','规格型号'),('unit','VARCHAR(20)','','计量单位'),('category_id','INT','FK','所属分类'),('cost_method','VARCHAR(10)','','计价方式(FIFO/LIFO)'),('upper_limit','DECIMAL(12,2)','','库存上限阈值'),('lower_limit','DECIMAL(12,2)','','库存下限阈值'),('price','DECIMAL(12,2)','','参考售价'),('status','TINYINT','','状态')]),
    ('stock','库存表',[('stock_id','INT','PK','库存编号'),('warehouse_id','INT','FK','仓库编号'),('goods_id','INT','FK','货品编号'),('quantity','DECIMAL(12,2)','','当前库存数量'),('total_cost','DECIMAL(12,2)','','库存占用资金')]),
    ('stock_batch','成本批次表',[('batch_id','INT','PK','批次编号'),('warehouse_id','INT','FK','仓库编号'),('goods_id','INT','FK','货品编号'),('inbound_item_id','INT','FK','来源入库明细'),('batch_no','VARCHAR(50)','','批次号'),('quantity','DECIMAL(12,2)','','批次剩余数量'),('unit_cost','DECIMAL(12,2)','','批次单位成本'),('inbound_date','DATE','','入库日期')]),
    ('inbound_order','入库单主表',[('inbound_id','INT','PK','入库单编号'),('order_no','VARCHAR(50)','UK','单据编号'),('biz_type','VARCHAR(20)','','业务类型'),('warehouse_id','INT','FK','入库仓库'),('supplier_id','INT','FK','供应商'),('operator_id','INT','FK','操作人'),('inbound_date','DATETIME','','入库日期'),('total_amount','DECIMAL(12,2)','','入库总金额'),('remark','VARCHAR(255)','','备注'),('status','TINYINT','','单据状态')]),
    ('inbound_item','入库明细表',[('item_id','INT','PK','明细编号'),('inbound_id','INT','FK','入库单编号'),('goods_id','INT','FK','货品编号'),('quantity','DECIMAL(12,2)','','入库数量'),('unit_price','DECIMAL(12,2)','','入库单价'),('amount','DECIMAL(12,2)','','金额')]),
    ('outbound_order','出库单主表',[('outbound_id','INT','PK','出库单编号'),('order_no','VARCHAR(50)','UK','单据编号'),('biz_type','VARCHAR(20)','','业务类型'),('warehouse_id','INT','FK','出库仓库'),('operator_id','INT','FK','操作人'),('outbound_date','DATETIME','','出库日期'),('total_cost','DECIMAL(12,2)','','出库总成本'),('total_amount','DECIMAL(12,2)','','出库总金额'),('remark','VARCHAR(255)','','备注'),('status','TINYINT','','单据状态')]),
    ('outbound_item','出库明细表',[('item_id','INT','PK','明细编号'),('outbound_id','INT','FK','出库单编号'),('goods_id','INT','FK','货品编号'),('quantity','DECIMAL(12,2)','','出库数量'),('unit_cost','DECIMAL(12,2)','','单位成本(FIFO/LIFO)'),('total_cost','DECIMAL(12,2)','','成本金额')]),
    ('transfer_order','调拨单主表',[('transfer_id','INT','PK','调拨单编号'),('order_no','VARCHAR(50)','UK','单据编号'),('from_warehouse_id','INT','FK','调出仓库'),('to_warehouse_id','INT','FK','调入仓库'),('operator_id','INT','FK','操作人'),('transfer_date','DATETIME','','调拨日期'),('remark','VARCHAR(255)','','备注'),('status','TINYINT','','单据状态')]),
    ('transfer_item','调拨明细表',[('item_id','INT','PK','明细编号'),('transfer_id','INT','FK','调拨单编号'),('goods_id','INT','FK','货品编号'),('quantity','DECIMAL(12,2)','','调拨数量')]),
    ('stocktake_order','盘点单主表',[('stocktake_id','INT','PK','盘点单编号'),('order_no','VARCHAR(50)','UK','单据编号'),('warehouse_id','INT','FK','盘点仓库'),('operator_id','INT','FK','操作人'),('stocktake_date','DATETIME','','盘点日期'),('remark','VARCHAR(255)','','备注'),('status','TINYINT','','单据状态')]),
    ('stocktake_item','盘点明细表',[('item_id','INT','PK','明细编号'),('stocktake_id','INT','FK','盘点单编号'),('goods_id','INT','FK','货品编号'),('book_quantity','DECIMAL(12,2)','','账面数量'),('actual_quantity','DECIMAL(12,2)','','实盘数量'),('diff_quantity','DECIMAL(12,2)','','差异数量'),('diff_type','VARCHAR(10)','','差异类型(GAIN/LOSS/NONE)')]),
    ('stock_alert','库存预警记录表',[('alert_id','INT','PK','预警编号'),('goods_id','INT','FK','货品编号'),('warehouse_id','INT','FK','仓库编号'),('alert_type','VARCHAR(10)','','预警类型(OVER/LOW)'),('current_quantity','DECIMAL(12,2)','','当前库存数量'),('threshold','DECIMAL(12,2)','','触发阈值'),('alert_time','DATETIME','','预警时间'),('status','TINYINT','','处理状态')]),
]

story = []
# 封面
story += [Spacer(1,2.2*cm), Paragraph('数据库课程设计报告', st_title), Spacer(1,0.4*cm),
          Paragraph('-------仓库管理系统', st_sub), Spacer(1,3.0*cm),
          Paragraph('计算机学院', st_ci), Paragraph('计算机科学与技术专业', st_ci), Paragraph('****级*班', st_ci),
          Paragraph('姓名：***', st_ci), Paragraph('学号：***********', st_ci), Spacer(1,2.0*cm),
          Paragraph('任课教师：***    实验教师：***', st_ci), PageBreak()]

toc = TableOfContents()
toc.levelStyles = [ParagraphStyle('t0', fontName=F, fontSize=12, leading=20, leftIndent=0),
                   ParagraphStyle('t1', fontName=F, fontSize=11, leading=18, leftIndent=22),
                   ParagraphStyle('t2', fontName=F, fontSize=10, leading=16, leftIndent=44)]
story += [Paragraph('目  录', st_toc), toc, PageBreak()]

# 一、系统开发平台
story += [H1('一、系统开发平台')]
story += [PN('题目：仓库管理系统'), PN('开发工具：Java（Spring Boot + MyBatis + Thymeleaf）'),
          PN('数据库：MySQL 8.0'), PN('操作系统：Windows 11'),
          P('本系统采用 B/S 架构，后端使用 Spring Boot 框架结合 MyBatis 持久层框架访问 MySQL 数据库，前端使用 Thymeleaf 模板引擎渲染页面。系统共设计 19 张数据表（业务表 11 张、辅助表 8 张），并落地视图、触发器、存储过程、事务等高级数据库对象。')]

# 二、数据库规划
story += [H1('二、数据库规划'), H2('2.1 任务陈述')]
story += [P('仓库管理系统面向企业仓储业务，用于解决传统手工台账与电子表格管理带来的三大突出问题：一是账实不符，出入库依赖人工记录，容易漏记错记，账面与实物不一致；二是出库成本核算不准确，同一货品不同批次进价不同，手工难以确定出库按哪个批次计价；三是查询统计困难，难以高效汇总任意时间段的出入库情况、各供应商供货金额、库存资金占用等。')]
story += [P('系统覆盖采购入库、销售出库、退货、领料、回料、仓库调拨、库存盘点等完整仓储流程。其中销售出库支持先进先出（FIFO）与后进先出（LIFO）两种出库成本核算方式；入库、出库、盘点、调拨、退货等高风险业务均通过事务保证数据一致性；库存低于下限或高于上限时自动生成预警记录。')]
story += [H2('2.2 任务目标')]
story += [P('（1）功能目标：实现仓储全流程业务信息化，支持系统管理员、仓库管理员、采购人员、领料人员四类角色协同操作，覆盖货品管理、采购入库、销售出库、领料回料、退货、调拨、盘点、库存查询、库存预警、统计报表等业务。')]
story += [P('（2）成本核算目标：实现 FIFO、LIFO 两种货品出库成本核算方式，为库存资金占用与经营分析提供准确依据。')]
story += [P('（3）决策支持目标：提供任意时间段库存查询、库存数量与占用资金汇总、多维度业务单据汇总报表。')]
story += [P('（4）风险控制目标：实现库存上下限自动预警，对退货、盘盈盘亏等异常业务严格事务处理与回滚，保证账实一致。')]
story += [P('（5）技术目标：严格遵循数据库第三范式设计，落地主外键完整性约束、索引、视图、触发器、存储过程、事务回滚等数据库技术。')]

# 三、系统定义
story += [H1('三、系统定义'), H2('3.1 系统边界')]
story += [P('系统划分为四类操作角色，职责边界清晰、权限相互隔离：系统管理员负责用户管理、角色权限管理、系统参数配置；仓库管理员是仓储业务核心执行者，负责货品管理、出入库、调拨、盘点、预警、成本核算、统计；采购人员负责供应商管理与采购入库登记、采购退货；领料人员负责领料申请与回料登记。')]
story += [P('系统业务边界覆盖采购、销售、领料、回料、调拨、盘点、退货等仓储流转环节，不涉及物品借还业务。')]
story += [H2('3.2 用户视图')]
story += [table(['角色','主要职责与可执行操作'], [
    ['系统管理员','用户管理、角色权限管理、系统参数配置'],
    ['仓库管理员','货品管理、采购入库、销售出库、领料回料、仓库调拨、库存盘点、库存查询、库存预警、统计报表'],
    ['采购人员','供应商管理、采购入库登记、采购退货'],
    ['领料人员','领料申请、回料登记'],
], [3.2*cm, 12.8*cm])]
story += [P('（1）系统管理员：数据需求为用户、角色、权限信息；事务需求为用户增删改查、角色权限分配、系统参数配置。')]
story += [P('（2）仓库管理员：数据需求为货品、库存、成本批次、出入库单、调拨单、盘点单、预警记录；事务需求为货品管理、采购入库、销售出库、领料回料、仓库调拨、库存盘点、库存查询、库存预警、统计报表。')]
story += [P('（3）采购人员：数据需求为供应商、采购入库单；事务需求为供应商管理、采购入库登记、采购退货。')]
story += [P('（4）领料人员：数据需求为领料、回料单据；事务需求为领料申请、回料登记。')]

# 四、需求分析
story += [H1('四、需求分析'), H2('4.1 用户需求说明'), H3('4.1.1 数据需求')]
story += [P('系统共设计 19 张数据表，按功能划分为六大模块：')]
story += [P('（1）系统权限模块：sys_user（用户）、sys_role（角色）、sys_permission（权限）、sys_role_permission（角色权限中间表），用于用户与基于角色的权限控制。')]
story += [P('（2）基础资料模块：goods_category（货品分类）、supplier（供应商）、warehouse（仓库）、goods（货品基础信息）。其中 goods 表含计价方式 cost_method、库存上下限阈值 upper_limit/lower_limit 等关键字段。')]
story += [P('（3）库存台账模块：stock（实时库存，按仓库+货品维度存数量与占用资金）、stock_batch（成本批次，按入库批次存剩余数量、单位成本、入库日期，支撑 FIFO/LIFO 核算）。')]
story += [P('（4）出入库单据模块：inbound_order/inbound_item（入库单主表/明细）、outbound_order/outbound_item（出库单主表/明细），统一承载采购、销售、退货、领料、回料、盘点、调拨等业务，用 biz_type 字段区分业务类型。')]
story += [P('（5）业务单据模块：transfer_order/transfer_item（调拨单主表/明细）、stocktake_order/stocktake_item（盘点单主表/明细）。')]
story += [P('（6）库存预警模块：stock_alert（预警记录表），由触发器自动写入。')]
story += [H3('4.1.2 事务需求')]
story += [P('系统涉及的高风险业务必须保证事务原子性，各业务事务如下：')]
story += [P('（1）采购入库：前置条件为货品、仓库、供应商存在且入库数量大于 0；操作写入库单主表、明细与成本批次，入库明细插入后触发器自动累加库存；异常时（数量非法等）整体回滚。')]
story += [P('（2）销售出库：前置条件为库存充足；操作按货品计价方式核算出库成本、写出库明细、审核通过后触发器扣减库存；库存不足时报错并回滚。')]
story += [P('（3）库存盘点：前置条件为货品、仓库存在且实盘数量非负；操作比对账面与实盘、生成盘盈盘亏记录并修正库存；实盘为负时回滚。')]
story += [P('（4）仓库调拨：前置条件为调出、调入仓库不同且源仓库存充足；操作源仓扣减、目标仓增加、写调拨明细；源仓不足时整体回滚。')]
story += [P('（5）退货处理：采购退货走出库方向、销售退货走入库方向，均在事务内执行，异常回滚。')]
story += [H2('4.2 系统需求说明')]
story += [P('功能需求：采购入库、销售出库（FIFO/LIFO 成本核算）、领料与回料、退货处理、仓库调拨、库存盘点、库存查询、库存预警、单据汇总统计。')]
story += [P('非功能需求：（1）数据一致性，入库、出库、盘点、调拨、退货等业务使用事务保证原子性，异常时整体回滚；（2）并发安全，采用 InnoDB 引擎行级锁与事务隔离，防止多人同时操作同一货品库存时超卖或错扣；（3）查询性能，对货品编号、单据日期、供应商编号、仓库编号等高频字段建立索引；（4）可维护性，表命名规范、字段中文注释、Java 分层架构。')]

# 五、数据库逻辑设计
story += [H1('五、数据库逻辑设计'), H2('5.1 ER 图')]
story += [P('系统 ER 图共包含 19 个实体，实体名与属性名采用英文命名。实体间联系以一对多为主：一个分类对应多个货品（GOODS_CATEGORY→GOODS）、一个供应商对应多张入库单（SUPPLIER→INBOUND_ORDER）、一个仓库对应多条库存记录（WAREHOUSE→STOCK）、一个货品对应多条库存与多个成本批次（GOODS→STOCK、GOODS→STOCK_BATCH）、一张入库单对应多条入库明细（INBOUND_ORDER→INBOUND_ITEM）、一个操作人经办多张单据（SYS_USER→各类单据）。')]
story += [P('多对多联系通过中间表/明细表拆分：角色与权限为多对多，通过中间表 sys_role_permission 拆成两个一对多；入库单与货品、出库单与货品本质亦为多对多，分别通过入库明细表 inbound_item、出库明细表 outbound_item 拆成两个一对多。')]
story += [P('调拨单存在双重关联：transfer_order 同时通过 from_warehouse_id、to_warehouse_id 关联仓库表，分别表示调出仓库与调入仓库。货品分类表 goods_category 通过 parent_id 自关联实现多级分类。')]
story += [P('实体间联系的基数如下：')]
story += [table(['联系（一方→多方）','基数','实现方式（外键）'], [
    ['角色—用户','1:N','sys_user.role_id'],
    ['角色—角色权限','1:N','sys_role_permission.role_id'],
    ['权限—角色权限','1:N','sys_role_permission.permission_id'],
    ['分类—货品','1:N','goods.category_id'],
    ['供应商—入库单','1:N','inbound_order.supplier_id'],
    ['仓库—库存','1:N','stock.warehouse_id'],
    ['货品—库存','1:N','stock.goods_id'],
    ['仓库—成本批次','1:N','stock_batch.warehouse_id'],
    ['货品—成本批次','1:N','stock_batch.goods_id'],
    ['入库明细—成本批次','1:N','stock_batch.inbound_item_id'],
    ['仓库—入库单','1:N','inbound_order.warehouse_id'],
    ['仓库—出库单','1:N','outbound_order.warehouse_id'],
    ['仓库—调拨单(调出)','1:N','transfer_order.from_warehouse_id'],
    ['仓库—调拨单(调入)','1:N','transfer_order.to_warehouse_id'],
    ['仓库—盘点单','1:N','stocktake_order.warehouse_id'],
    ['仓库—预警记录','1:N','stock_alert.warehouse_id'],
    ['入库单—入库明细','1:N','inbound_item.inbound_id'],
    ['货品—入库明细','1:N','inbound_item.goods_id'],
    ['出库单—出库明细','1:N','outbound_item.outbound_id'],
    ['货品—出库明细','1:N','outbound_item.goods_id'],
    ['调拨单—调拨明细','1:N','transfer_item.transfer_id'],
    ['货品—调拨明细','1:N','transfer_item.goods_id'],
    ['盘点单—盘点明细','1:N','stocktake_item.stocktake_id'],
    ['货品—盘点明细','1:N','stocktake_item.goods_id'],
    ['货品—预警记录','1:N','stock_alert.goods_id'],
    ['用户—入库单','1:N','inbound_order.operator_id'],
    ['用户—出库单','1:N','outbound_order.operator_id'],
    ['用户—调拨单','1:N','transfer_order.operator_id'],
    ['用户—盘点单','1:N','stocktake_order.operator_id'],
], [6.2*cm, 1.8*cm, 8*cm])]
story += [table(['联系','基数','实现方式'], [
    ['角色—权限','M:N','中间表 sys_role_permission'],
    ['入库单—货品','M:N','入库明细 inbound_item 拆'],
    ['出库单—货品','M:N','出库明细 outbound_item 拆'],
    ['分类—分类','自关联 1:N','goods_category.parent_id'],
    ['调拨单—仓库','双重关联','from/to_warehouse_id'],
], [6.2*cm, 1.8*cm, 8*cm])]
story += [PH('【图 5-1 系统 ER 图】（此处预留，请手动插入 ER 图）')]
story += [H2('5.2 数据字典')]
story += [P('系统 19 张数据表的完整字段字典如下：')]
for name, cname, fields in TABLES:
    story += [H3(name + '（' + cname + '）')]
    story += [table(['字段名','数据类型','键','说明'], fields, [3.4*cm, 3.0*cm, 1.8*cm, 7.8*cm])]
story += [H2('5.3 关系表')]
story += [P('核心关系表结构说明：goods 表存货品编码（goods_code 唯一）、名称、规格、单位、计价方式 cost_method（FIFO/LIFO）、库存上限 upper_limit、下限 lower_limit；stock 表按 warehouse_id + goods_id 联合唯一存实时数量 quantity 与占用资金 total_cost；stock_batch 表存每批入库的剩余数量、单位成本 unit_cost、入库日期 inbound_date，作为 FIFO/LIFO 核算依据；出入库、调拨、盘点单据均为主表+明细结构，主表存单据头（单号、仓库、操作人、业务类型 biz_type、状态），明细表存每一行货品（数量、单价/成本、金额）。')]
story += [P('19 张数据表的关系模式如下（主键、外键已标注）：')]
story += [PN('sys_user(user_id, username, password, real_name, role_id, phone, email, status, created_at)，主键 user_id，外键 role_id')]
story += [PN('sys_role(role_id, role_name, role_code, description)，主键 role_id')]
story += [PN('sys_permission(permission_id, permission_name, permission_code, description)，主键 permission_id')]
story += [PN('sys_role_permission(id, role_id, permission_id)，主键 id，外键 role_id、permission_id')]
story += [PN('goods_category(category_id, category_name, parent_id, description)，主键 category_id，外键 parent_id')]
story += [PN('supplier(supplier_id, supplier_name, contact_name, phone, address, email, status)，主键 supplier_id')]
story += [PN('warehouse(warehouse_id, warehouse_name, location, manager, phone)，主键 warehouse_id')]
story += [PN('goods(goods_id, goods_code, goods_name, spec, unit, category_id, cost_method, upper_limit, lower_limit, price, status)，主键 goods_id，外键 category_id')]
story += [PN('stock(stock_id, warehouse_id, goods_id, quantity, total_cost)，主键 stock_id，外键 warehouse_id、goods_id')]
story += [PN('stock_batch(batch_id, warehouse_id, goods_id, inbound_item_id, batch_no, quantity, unit_cost, inbound_date)，主键 batch_id，外键 warehouse_id、goods_id、inbound_item_id')]
story += [PN('inbound_order(inbound_id, order_no, biz_type, warehouse_id, supplier_id, operator_id, inbound_date, total_amount, remark, status)，主键 inbound_id，外键 warehouse_id、supplier_id、operator_id')]
story += [PN('inbound_item(item_id, inbound_id, goods_id, quantity, unit_price, amount)，主键 item_id，外键 inbound_id、goods_id')]
story += [PN('outbound_order(outbound_id, order_no, biz_type, warehouse_id, operator_id, outbound_date, total_cost, total_amount, remark, status)，主键 outbound_id，外键 warehouse_id、operator_id')]
story += [PN('outbound_item(item_id, outbound_id, goods_id, quantity, unit_cost, total_cost)，主键 item_id，外键 outbound_id、goods_id')]
story += [PN('transfer_order(transfer_id, order_no, from_warehouse_id, to_warehouse_id, operator_id, transfer_date, remark, status)，主键 transfer_id，外键 from_warehouse_id、to_warehouse_id、operator_id')]
story += [PN('transfer_item(item_id, transfer_id, goods_id, quantity)，主键 item_id，外键 transfer_id、goods_id')]
story += [PN('stocktake_order(stocktake_id, order_no, warehouse_id, operator_id, stocktake_date, remark, status)，主键 stocktake_id，外键 warehouse_id、operator_id')]
story += [PN('stocktake_item(item_id, stocktake_id, goods_id, book_quantity, actual_quantity, diff_quantity, diff_type)，主键 item_id，外键 stocktake_id、goods_id')]
story += [PN('stock_alert(alert_id, goods_id, warehouse_id, alert_type, current_quantity, threshold, alert_time, status)，主键 alert_id，外键 goods_id、warehouse_id')]
story += [P('第三范式逐项分析：')]
story += [P('第一范式（1NF）：所有字段原子、无重复组。出入库、调拨、盘点单据均采用主表+明细表拆分，一张入库单的多个货品通过 inbound_item 逐行存储，避免同一行存储多个货品明细。')]
story += [P('第二范式（2NF）：各表均以单一主键标识，不存在复合主键导致的部分函数依赖。明细表主键为 item_id，非主键属性（数量、单价、金额）完全依赖主键，不依赖主键的一部分。')]
story += [P('第三范式（3NF）：各表消除传递依赖。典型体现：入库单主表仅存 supplier_id，供应商名称、联系方式存于 supplier 表，消除供应商属性对入库单的传递依赖；明细表仅存 goods_id，货品名称、规格、计价方式存于 goods 表；库存、单据表仅存 warehouse_id，仓库名称、位置存于 warehouse 表；出库明细存计算结果 unit_cost，批次剩余数量与单价存于 stock_batch 表，避免互相传递依赖。')]
story += [P('主表-明细拆分收益：若不拆分，一张入库单要存储多个货品，要么一行一个货品、单号重复出现（数据冗余），要么一行存储多个货品（违反第一范式）。拆成 inbound_order 与 inbound_item 后，主表管单据头，明细表管每一行货品，既满足范式，又便于统计汇总与后续扩展。')]

# 六、数据库物理设计
story += [H1('六、数据库物理设计'), H2('6.1 索引')]
story += [P('对高频查询字段建立索引：goods 表按 goods_code 建唯一索引、按 category_id/goods_name 建普通索引；stock 表按 warehouse_id+goods_id 建联合唯一索引；stock_batch 表按 warehouse_id+goods_id+inbound_date 建联合索引（支撑 FIFO/LIFO 批次扣减查询）；inbound_order 表按 warehouse_id、supplier_id、inbound_date、biz_type 建索引；outbound_order 表按 warehouse_id、outbound_date、biz_type 建索引；transfer_order 表按 from_warehouse_id、to_warehouse_id 建索引；stock_alert 表按 goods_id、warehouse_id、status 建索引。')]
story += [H2('6.2 视图')]
story += [P('共创建 4 个视图：v_stock_overview（实时库存总览，展示货品、仓库、分类、当前库存数量、占用资金、上下限阈值、计价方式及库存状态）；v_stock_warning（超储/短缺预警货品，实时筛选高于上限或低于下限的货品）；v_inout_summary（出入库明细汇总，用 flow_type 区分方向）；v_stock_batch_cost（FIFO/LIFO 成本批次，展示各批次剩余数量、单位成本、剩余成本与入库日期）。视图封装常用查询，简化应用层开发。')]
story += [H2('6.3 安全机制')]
story += [P('采用基于角色的访问控制，通过 sys_user、sys_role、sys_permission、sys_role_permission 四张表实现；通过主外键完整性约束、唯一约束、非空约束防止非法数据写入；库存数量、批次数量、上下限通过 CHECK 约束保证非负与合理（如 chk_stock_quantity CHECK quantity>=0、chk_goods_limit CHECK upper_limit>=lower_limit）。')]
story += [H2('6.4 其他')]
story += [P('触发器（共 8 个，统一 AFTER 时机）：trg_inbound_item_after_insert 入库明细插入后自动累加库存；trg_outbound_order_after_approve 出库单审核通过后自动扣减库存；trg_stock_after_insert / trg_stock_after_update 库存变动后判断超储/短缺并写入预警记录；trg_inbound_item_after_delete/update、trg_outbound_item_after_delete/update 明细删除或修改时反向回滚库存。')]
story += [P('存储过程（共 4 个，全部内置事务与异常回滚）：sp_inbound 货品入库（写入库单主表+明细+成本批次）；sp_outbound_cost 出库成本核算（按 cost_method 用游标遍历成本批次，FIFO 升序、LIFO 降序扣减，汇总出库成本）；sp_stocktake 库存盘点（盘盈盘亏处理，写盘点记录并修正库存）；sp_transfer 批量调拨（支持 JSON 多货品明细，源仓扣减、目标仓增加）。统一通过 OUT 参数 p_status_code、p_status_msg 返回执行状态。')]
story += [P('FIFO/LIFO 成本核算原理：出库时读取货品 cost_method，FIFO 按入库日期升序扣减成本批次、LIFO 按降序扣减，逐批扣减至出库数量扣完，累加出库总成本，单位成本=总成本/出库数量，写入出库明细 unit_cost/total_cost。')]

# 七、应用程序设计
story += [H1('七、应用程序设计'), H2('7.1 功能模块')]
story += [P('系统采用 Java 分层架构：Controller（控制层，接收请求与页面跳转）、Service（业务层，参数校验与业务组装）、Mapper（数据访问层，表查询、视图查询、存储过程调用）、Entity（实体层，与表/视图字段对应）。业务逻辑下沉数据库，Java 层仅组装参数、调用存储过程并读取返回状态。')]
story += [H2('7.2 界面设计')]
story += [P('系统提供 12 个业务页面：登录主页、货品管理、采购入库、销售出库、领料出库、回料入库、退货处理、库存盘点、仓库调拨、库存查询、库存预警、统计报表。页面采用基础表格与表单，样式简洁统一，操作均有成功/失败提示，预警使用红黄标签区分。')]
story += [PH('（此处预留，请手动插入各功能界面截图）')]
story += [H2('7.3 事务设计')]
story += [P('（1）采购入库：调用 sp_inbound，写入库单主表、明细与成本批次，入库明细插入后由触发器自动累加库存。')]
story += [P('（2）销售出库：调用 sp_outbound_cost，按货品计价方式核算出库成本，审核通过后由触发器扣减库存。')]
story += [P('（3）领料出库：复用出库过程 sp_outbound_cost，biz_type 取 MATERIAL_ISSUE。')]
story += [P('（4）回料入库：复用入库过程 sp_inbound，biz_type 取 MATERIAL_RETURN。')]
story += [P('（5）退货处理：采购退货走出库方向（biz_type=PURCHASE_RETURN），销售退货走入库方向（biz_type=SALE_RETURN）。')]
story += [P('（6）库存盘点：调用 sp_stocktake，比对账面与实盘，生成盘盈（GAIN）盘亏（LOSS）记录并修正库存。')]
story += [P('（7）仓库调拨：调用 sp_transfer，源仓扣减、目标仓增加，同一事务内任一项失败整体回滚。')]
story += [P('（8）库存预警：入库/出库引起库存变动后，触发器判断是否低于下限或高于上限，自动写入 stock_alert 预警记录。')]

# 八、测试和运行
story += [H1('八、测试和运行')]
story += [P('测试数据量：基础实体表（角色、用户、分类、供应商、仓库、货品）各插入 30 条测试数据；全库关联记录共 204 条（入库明细 96 条、成本批次 96 条、出库明细 4 条、盘点明细 3 条、调拨明细 5 条），满足课程"实体测试数据不少于 30 条、全库关联测试数据不少于 200 条"的要求。测试数据覆盖正常单据、退货单据、盘盈盘亏异常单据、调拨单据。')]
story += [P('核心业务测试案例：')]
story += [table(['序号','测试业务','输入','预期结果'], [
    ['1','采购入库','货品1 入库 100@5、50@6','库存 150，占用资金 800'],
    ['2','FIFO 出库','货品1 出库 120','出库成本 620（100×5+20×6）'],
    ['3','LIFO 出库','货品2 出库 120','出库成本 650（50×6+70×5）'],
    ['4','领料出库','货品3 领料 10','库存扣减（MATERIAL_ISSUE）'],
    ['5','回料入库','货品3 回料 5@4','库存回增（MATERIAL_RETURN）'],
    ['6','退货处理','采购退货 5 / 销售退货 8','库存相应增减'],
    ['7','盘点盘盈','货品5 实盘 100','GAIN，库存修正 100'],
    ['8','盘点盘亏','货品6 实盘 5','LOSS，触发 LOW 预警'],
    ['9','仓库调拨','仓库1→仓库2 货品1 10','源减目标增'],
    ['10','库存不足','出库数量超库存','报错，库存不变'],
    ['11','调拨回滚','调拨源仓不足','报错并整体回滚'],
    ['12','盘点负数','实盘 -1','报错「实盘数量不能为负」'],
], [1.2*cm, 2.2*cm, 4.2*cm, 8.4*cm])]
story += [P('运行说明：先依次执行 code/sql/01~05 脚本完成建表、视图、触发器、存储过程、测试数据；复制 code/src/.env.example 为 code/src/.env 并填写本机数据库密码；在 code/src 目录启动 Spring Boot 后访问 http://localhost:8080，使用 user01/123456 登录，即可演示采购入库、销售出库（FIFO/LIFO）、盘点、调拨、统计报表等核心业务。')]

# 九、总结
story += [H1('九、总结')]
story += [P('本设计完整经历了需求分析、概念结构设计（ER 图）、逻辑结构设计（三范式）、物理结构设计（建表与索引）、高级数据库对象（视图、触发器、存储过程、事务）到 Java 后端集成实现的全过程。通过将 FIFO/LIFO 成本核算、库存自动联动、预警生成下沉到数据库侧，简化了应用层复杂度，突出了数据库课程设计重点；通过事务回滚保证了退货、盘点、调拨等异常业务的数据一致性。')]
story += [P('通过本设计，深刻体会到：三范式是逻辑设计的基础，通过消除部分依赖与传递依赖有效避免数据冗余；存储过程与触发器能大幅简化应用层，将业务逻辑下沉数据库；事务是数据一致性的保障；索引与视图提升查询性能与可维护性。')]

# 附、参考文献
story += [H1('附. 参考文献')]
story += [PN('[1] 王珊, 萨师煊. 数据库系统概论（第5版）. 高等教育出版社, 2014.')]
story += [PN('[2] 周志逵, 郭贵锁. 数据库系统原理. 清华大学出版社, 2007.')]
story += [PN('[3] Baron Schwartz, Peter Zaitsev, Vadim Tkachenko. 高性能 MySQL（第3版）. 电子工业出版社, 2013.')]
story += [PN('[4] Craig Walls. Spring Boot 实战. 人民邮电出版社, 2016.')]

doc = ReportDoc('仓库管理系统课程设计报告.pdf', pagesize=A4,
                leftMargin=2.2*cm, rightMargin=2.2*cm, topMargin=2.2*cm, bottomMargin=2.2*cm,
                title='仓库管理系统课程设计报告')
doc.multiBuild(story, onFirstPage=on_first, onLaterPages=on_later)
print('PDF generated OK')
