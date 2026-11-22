package com.warehouse.mapper;

import com.warehouse.entity.Warehouse;
import org.apache.ibatis.annotations.Select;

import java.util.List;

/**
 * 仓库 DAO 层
 */
public interface WarehouseMapper {

    @Select("SELECT * FROM warehouse ORDER BY warehouse_id")
    List<Warehouse> list();

    @Select("SELECT * FROM warehouse WHERE warehouse_id = #{id}")
    Warehouse getById(Integer id);
}
