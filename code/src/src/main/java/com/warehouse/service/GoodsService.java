package com.warehouse.service;

import com.warehouse.entity.Goods;
import com.warehouse.mapper.GoodsMapper;
import com.warehouse.util.BusinessException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 货品管理服务（参数校验 + 业务组装）
 */
@Service
public class GoodsService {

    private final GoodsMapper goodsMapper;

    public GoodsService(GoodsMapper goodsMapper) {
        this.goodsMapper = goodsMapper;
    }

    public List<Goods> list() {
        return goodsMapper.list();
    }

    public List<Goods> listActive() {
        return goodsMapper.listActive();
    }

    public Goods getById(Integer id) {
        return goodsMapper.getById(id);
    }

    @Transactional(rollbackFor = Exception.class)
    public void save(Goods goods) {
        if (goods.getGoodsName() == null || goods.getGoodsName().trim().isEmpty()) {
            throw new BusinessException("货品名称不能为空");
        }
        if (goods.getCostMethod() == null || !("FIFO".equals(goods.getCostMethod()) || "LIFO".equals(goods.getCostMethod()))) {
            throw new BusinessException("计价方式只能为 FIFO 或 LIFO");
        }
        if (goods.getGoodsId() == null) {
            goodsMapper.insert(goods);
        } else {
            goodsMapper.update(goods);
        }
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateStatus(Integer id, Integer status) {
        goodsMapper.updateStatus(id, status);
    }

    @Transactional(rollbackFor = Exception.class)
    public void delete(Integer id) {
        if (goodsMapper.countReferences(id) > 0) {
            throw new BusinessException("该货品已被业务数据引用，不能删除，只能停用");
        }
        goodsMapper.delete(id);
    }
}
