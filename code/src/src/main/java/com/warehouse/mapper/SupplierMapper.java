package com.warehouse.mapper;

import com.warehouse.entity.Supplier;
import org.apache.ibatis.annotations.Select;

import java.util.List;

/**
 * 供应商 DAO 层
 */
public interface SupplierMapper {

    @Select("SELECT * FROM supplier ORDER BY supplier_id")
    List<Supplier> list();

    @Select("SELECT * FROM supplier WHERE supplier_id = #{id}")
    Supplier getById(Integer id);
}
