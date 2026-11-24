package com.warehouse.controller;

import com.warehouse.util.RequirePermission;
import com.warehouse.service.StockService;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 库存查询 / 预警 / 统计报表控制器
 */
@Controller
public class StockController {
    private final StockService stockService;
    public StockController(StockService stockService) {
        this.stockService = stockService;
    }
    @GetMapping("/stock")
    @RequirePermission("stock:view")
    public String stock(Model model) {
        model.addAttribute("stockList", stockService.stockOverview());
        return "stock";
    }
    @GetMapping("/warning")
    @RequirePermission("biz:warning")
    public String warning(@RequestParam(defaultValue = "realtime") String tab, Model model) {
        model.addAttribute("activeTab", tab);
        if ("records".equals(tab)) {
            model.addAttribute("alertList", stockService.stockAlerts());
        } else {
            model.addAttribute("warningList", stockService.stockWarning());
        }
        return "warning";
    }
    @GetMapping("/report")
    @RequirePermission("report:view")
    public String report(Model model) {
        model.addAttribute("inout", stockService.inoutSummary());
        model.addAttribute("supplierSupply", stockService.supplierSupply());
        model.addAttribute("stocktakeDiff", stockService.stocktakeDiff());
        return "report";
    }
}
