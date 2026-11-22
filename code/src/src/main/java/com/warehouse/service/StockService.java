package com.warehouse.service;

import com.warehouse.entity.StockView;
import com.warehouse.mapper.StockMapper;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

/**
 * 库存查询 / 预警 / 统计报表服务
 */
@Service
public class StockService {

    private final StockMapper stockMapper;

    public StockService(StockMapper stockMapper) {
        this.stockMapper = stockMapper;
    }

    public List<StockView> stockOverview() {
        return stockMapper.listOverview();
    }

    public List<Map<String, Object>> stockWarning() {
        return stockMapper.listWarning();
    }

    public List<Map<String, Object>> stockAlerts() {
        return stockMapper.listAlerts();
    }

    public List<Map<String, Object>> inoutSummary() {
        return stockMapper.inoutSummary();
    }

    public List<Map<String, Object>> supplierSupply() {
        return stockMapper.supplierSupply();
    }

    public List<Map<String, Object>> stocktakeDiff() {
        return stockMapper.stocktakeDiff();
    }

    public String getStockStatus(Integer warehouseId, Integer goodsId) {
        return stockMapper.getStockStatus(warehouseId, goodsId);
    }
}
