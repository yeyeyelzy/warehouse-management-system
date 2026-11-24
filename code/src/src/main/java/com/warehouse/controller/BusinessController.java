package com.warehouse.controller;

import com.warehouse.util.RequirePermission;
import com.warehouse.entity.SysUser;
import com.warehouse.mapper.GoodsMapper;
import com.warehouse.mapper.SupplierMapper;
import com.warehouse.mapper.WarehouseMapper;
import com.warehouse.service.BusinessService;
import com.warehouse.service.StockService;
import com.warehouse.util.BusinessException;
import com.warehouse.util.ProcedureResult;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;
import javax.servlet.http.HttpSession;
import java.math.BigDecimal;

/**
 * 核心业务控制器：采购入库 / 销售出库 / 领料出库 / 回料入库 / 退货 / 盘点 / 调拨
 */
@Controller
@RequestMapping("/biz")
public class BusinessController {
    private final BusinessService businessService;
    private final WarehouseMapper warehouseMapper;
    private final GoodsMapper goodsMapper;
    private final SupplierMapper supplierMapper;
    private final StockService stockService;
    public BusinessController(BusinessService businessService,
                              WarehouseMapper warehouseMapper,
                              GoodsMapper goodsMapper,
                              SupplierMapper supplierMapper,
                              StockService stockService) {
        this.businessService = businessService;
        this.warehouseMapper = warehouseMapper;
        this.goodsMapper = goodsMapper;
        this.supplierMapper = supplierMapper;
        this.stockService = stockService;
    }
    /** 公共下拉数据 */
    private void addOptions(Model model) {
        model.addAttribute("warehouses", warehouseMapper.list());
        model.addAttribute("goodsList", goodsMapper.listActive());
        model.addAttribute("suppliers", supplierMapper.list());
    }
    private Integer operatorId(HttpSession session) {
        Object user = session.getAttribute("loginUser");
        return user instanceof SysUser ? ((SysUser) user).getUserId() : 1;
    }
    /** 出入库后检查库存是否超储/短缺，越界则添加提示 */
    private void checkStockWarning(Integer warehouseId, Integer goodsId, RedirectAttributes ra) {
        String status = stockService.getStockStatus(warehouseId, goodsId);
        if ("LOW".equals(status)) {
            ra.addFlashAttribute("warning", "提示：该货品库存已低于下限，请及时补货！");
        } else if ("OVER".equals(status)) {
            ra.addFlashAttribute("warning", "提示：该货品库存已高于上限，请注意超储！");
        }
    }
    /** 调拨后检查：调出仓可能短缺、调入仓可能超储 */
    private void checkTransferWarning(Integer fromWarehouseId, Integer toWarehouseId, Integer goodsId, RedirectAttributes ra) {
        String fromStatus = stockService.getStockStatus(fromWarehouseId, goodsId);
        String toStatus = stockService.getStockStatus(toWarehouseId, goodsId);
        if ("LOW".equals(fromStatus) && "OVER".equals(toStatus)) {
            ra.addFlashAttribute("warning", "提示：调出仓库库存已低于下限，调入仓库库存已高于上限，请及时处理！");
        } else if ("LOW".equals(fromStatus)) {
            ra.addFlashAttribute("warning", "提示：调出仓库该货品库存已低于下限，请及时补货！");
        } else if ("OVER".equals(toStatus)) {
            ra.addFlashAttribute("warning", "提示：调入仓库该货品库存已高于上限，请注意超储！");
        }
    }
    // ============ 采购入库 ============
    @GetMapping("/inbound")
    @RequirePermission("biz:inbound")
    public String inboundPage(Model model) {
        addOptions(model);
        return "inbound";
    }
    @PostMapping("/inbound")
    @RequirePermission("biz:inbound")
    public String inbound(@RequestParam Integer warehouseId,
                          @RequestParam Integer goodsId,
                          @RequestParam BigDecimal quantity,
                          @RequestParam BigDecimal unitPrice,
                          @RequestParam(required = false) Integer supplierId,
                          HttpSession session, RedirectAttributes ra) {
        try {
            businessService.inbound(warehouseId, goodsId, quantity, unitPrice, operatorId(session), supplierId, "PURCHASE");
            ra.addFlashAttribute("success", "采购入库成功");
            checkStockWarning(warehouseId, goodsId, ra);
        } catch (BusinessException e) {
            ra.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/biz/inbound";
    }
    // ============ 销售出库（FIFO/LIFO 成本核算） ============
    @GetMapping("/outbound")
    @RequirePermission("biz:outbound")
    public String outboundPage(Model model) {
        addOptions(model);
        return "outbound";
    }
    @PostMapping("/outbound")
    @RequirePermission("biz:outbound")
    public String outbound(@RequestParam Integer warehouseId,
                           @RequestParam Integer goodsId,
                           @RequestParam BigDecimal quantity,
                           HttpSession session, RedirectAttributes ra) {
        try {
            ProcedureResult r = businessService.outbound(warehouseId, goodsId, quantity, operatorId(session), "SALE");
            ra.addFlashAttribute("success", "销售出库成功，出库成本 = " + r.getOutTotalCost());
            checkStockWarning(warehouseId, goodsId, ra);
        } catch (BusinessException e) {
            ra.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/biz/outbound";
    }
    // ============ 领料出库 ============
    @GetMapping("/materialIssue")
    @RequirePermission("biz:apply")
    public String materialIssuePage(Model model) {
        addOptions(model);
        return "materialIssue";
    }
    @PostMapping("/materialIssue")
    @RequirePermission("biz:apply")
    public String materialIssue(@RequestParam Integer warehouseId,
                                @RequestParam Integer goodsId,
                                @RequestParam BigDecimal quantity,
                                HttpSession session, RedirectAttributes ra) {
        try {
            businessService.outbound(warehouseId, goodsId, quantity, operatorId(session), "MATERIAL_ISSUE");
            ra.addFlashAttribute("success", "领料出库成功");
            checkStockWarning(warehouseId, goodsId, ra);
        } catch (BusinessException e) {
            ra.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/biz/materialIssue";
    }
    // ============ 回料入库 ============
    @GetMapping("/materialReturn")
    @RequirePermission("biz:materialReturn")
    public String materialReturnPage(Model model) {
        addOptions(model);
        return "materialReturn";
    }
    @PostMapping("/materialReturn")
    @RequirePermission("biz:materialReturn")
    public String materialReturn(@RequestParam Integer warehouseId,
                                 @RequestParam Integer goodsId,
                                 @RequestParam BigDecimal quantity,
                                 @RequestParam BigDecimal unitPrice,
                                 HttpSession session, RedirectAttributes ra) {
        try {
            businessService.inbound(warehouseId, goodsId, quantity, unitPrice, operatorId(session), null, "MATERIAL_RETURN");
            ra.addFlashAttribute("success", "回料入库成功");
            checkStockWarning(warehouseId, goodsId, ra);
        } catch (BusinessException e) {
            ra.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/biz/materialReturn";
    }
    // ============ 退货处理 ============
    @GetMapping("/return")
    @RequirePermission("biz:purchaseReturn")
    public String returnPage(Model model) {
        addOptions(model);
        return "return";
    }
    @PostMapping("/return")
    @RequirePermission("biz:purchaseReturn")
    public String doReturn(@RequestParam Integer warehouseId,
                           @RequestParam Integer goodsId,
                           @RequestParam BigDecimal quantity,
                           @RequestParam String returnType,
                           @RequestParam(required = false) BigDecimal unitPrice,
                           HttpSession session, RedirectAttributes ra) {
        try {
            if ("PURCHASE_RETURN".equals(returnType)) {
                // 采购退货：出库方向
                businessService.outbound(warehouseId, goodsId, quantity, operatorId(session), "PURCHASE_RETURN");
                ra.addFlashAttribute("success", "采购退货出库成功");
            } else {
                // 销售退货：入库方向
                BigDecimal price = unitPrice == null ? BigDecimal.ZERO : unitPrice;
                businessService.inbound(warehouseId, goodsId, quantity, price, operatorId(session), null, "SALE_RETURN");
                ra.addFlashAttribute("success", "销售退货入库成功");
            }
            checkStockWarning(warehouseId, goodsId, ra);
        } catch (BusinessException e) {
            ra.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/biz/return";
    }
    // ============ 库存盘点 ============
    @GetMapping("/stocktake")
    @RequirePermission("biz:check")
    public String stocktakePage(Model model) {
        addOptions(model);
        return "stocktake";
    }
    @PostMapping("/stocktake")
    @RequirePermission("biz:check")
    public String stocktake(@RequestParam Integer warehouseId,
                            @RequestParam Integer goodsId,
                            @RequestParam BigDecimal actualQuantity,
                            HttpSession session, RedirectAttributes ra) {
        try {
            ProcedureResult r = businessService.stocktake(warehouseId, goodsId, actualQuantity, operatorId(session));
            ra.addFlashAttribute("success", r.getStatusMsg());
        } catch (BusinessException e) {
            ra.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/biz/stocktake";
    }
    // ============ 仓库调拨 ============
    @GetMapping("/transfer")
    @RequirePermission("biz:transfer")
    public String transferPage(Model model) {
        addOptions(model);
        return "transfer";
    }
    @PostMapping("/transfer")
    @RequirePermission("biz:transfer")
    public String transfer(@RequestParam Integer fromWarehouseId,
                           @RequestParam Integer toWarehouseId,
                           @RequestParam Integer goodsId,
                           @RequestParam BigDecimal quantity,
                           HttpSession session, RedirectAttributes ra) {
        try {
            // 组装 JSON 明细（底层存储过程支持多货品批量 JSON）
            String itemsJson = String.format("[{\"goods_id\":%d,\"quantity\":%s}]", goodsId, quantity.toPlainString());
            ProcedureResult r = businessService.transfer(fromWarehouseId, toWarehouseId, operatorId(session), itemsJson);
            ra.addFlashAttribute("success", r.getStatusMsg());
            checkTransferWarning(fromWarehouseId, toWarehouseId, goodsId, ra);
        } catch (BusinessException e) {
            ra.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/biz/transfer";
    }
}
