package com.warehouse.controller;

import com.warehouse.entity.Goods;
import com.warehouse.service.GoodsService;
import com.warehouse.util.BusinessException;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.mvc.support.RedirectAttributes;

/**
 * 货品管理控制器
 */
@Controller
@RequestMapping("/goods")
public class GoodsController {

    private final GoodsService goodsService;

    public GoodsController(GoodsService goodsService) {
        this.goodsService = goodsService;
    }

    @GetMapping
    public String list(Model model) {
        model.addAttribute("goodsList", goodsService.list());
        model.addAttribute("goods", new Goods());
        return "goods";
    }

    @GetMapping("/edit/{id}")
    public String edit(@PathVariable Integer id, Model model) {
        model.addAttribute("goodsList", goodsService.list());
        model.addAttribute("goods", goodsService.getById(id));
        return "goods";
    }

    @PostMapping("/save")
    public String save(Goods goods, RedirectAttributes redirectAttributes) {
        try {
            goodsService.save(goods);
            redirectAttributes.addFlashAttribute("success", goods.getGoodsId() == null ? "新增货品成功" : "更新货品成功");
        } catch (BusinessException e) {
            redirectAttributes.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/goods";
    }

    @PostMapping("/disable/{id}")
    public String disable(@PathVariable Integer id, RedirectAttributes redirectAttributes) {
        goodsService.updateStatus(id, 0);
        redirectAttributes.addFlashAttribute("success", "货品已停用");
        return "redirect:/goods";
    }

    @PostMapping("/enable/{id}")
    public String enable(@PathVariable Integer id, RedirectAttributes redirectAttributes) {
        goodsService.updateStatus(id, 1);
        redirectAttributes.addFlashAttribute("success", "货品已启用");
        return "redirect:/goods";
    }

    @PostMapping("/delete/{id}")
    public String delete(@PathVariable Integer id, RedirectAttributes redirectAttributes) {
        try {
            goodsService.delete(id);
            redirectAttributes.addFlashAttribute("success", "删除货品成功");
        } catch (BusinessException e) {
            redirectAttributes.addFlashAttribute("error", e.getMessage());
        }
        return "redirect:/goods";
    }
}
