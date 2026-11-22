package com.warehouse.mapper;

import com.warehouse.entity.Goods;
import org.apache.ibatis.annotations.*;

import java.util.List;

/**
 * 货品 DAO 层
 */
public interface GoodsMapper {

    @Select("SELECT * FROM goods ORDER BY goods_id")
    List<Goods> list();

    @Select("SELECT * FROM goods WHERE status = 1 ORDER BY goods_id")
    List<Goods> listActive();

    @Select("SELECT * FROM goods WHERE goods_id = #{id}")
    Goods getById(Integer id);

    @Insert("INSERT INTO goods(goods_code, goods_name, spec, unit, category_id, cost_method, upper_limit, lower_limit, price, status) " +
            "VALUES(#{goodsCode}, #{goodsName}, #{spec}, #{unit}, #{categoryId}, #{costMethod}, #{upperLimit}, #{lowerLimit}, #{price}, #{status})")
    @Options(useGeneratedKeys = true, keyProperty = "goodsId")
    int insert(Goods goods);

    @Update("UPDATE goods SET goods_code=#{goodsCode}, goods_name=#{goodsName}, spec=#{spec}, unit=#{unit}, " +
            "category_id=#{categoryId}, cost_method=#{costMethod}, upper_limit=#{upperLimit}, " +
            "lower_limit=#{lowerLimit}, price=#{price}, status=#{status} WHERE goods_id=#{goodsId}")
    int update(Goods goods);

    @Update("UPDATE goods SET status = #{status} WHERE goods_id = #{goodsId}")
    int updateStatus(@Param("goodsId") Integer goodsId, @Param("status") Integer status);

    @Select("SELECT (SELECT COUNT(*) FROM stock WHERE goods_id = #{goodsId}) " +
            "+ (SELECT COUNT(*) FROM stock_batch WHERE goods_id = #{goodsId}) " +
            "+ (SELECT COUNT(*) FROM inbound_item WHERE goods_id = #{goodsId}) " +
            "+ (SELECT COUNT(*) FROM outbound_item WHERE goods_id = #{goodsId}) " +
            "+ (SELECT COUNT(*) FROM transfer_item WHERE goods_id = #{goodsId}) " +
            "+ (SELECT COUNT(*) FROM stocktake_item WHERE goods_id = #{goodsId}) " +
            "+ (SELECT COUNT(*) FROM stock_alert WHERE goods_id = #{goodsId})")
    int countReferences(@Param("goodsId") Integer goodsId);

    @Delete("DELETE FROM goods WHERE goods_id = #{goodsId}")
    int delete(@Param("goodsId") Integer goodsId);
}
