package com.warehouse.util;

import org.springframework.stereotype.Component;

/**
 * DeepSeek API 自然语言转 SQL 客户端（预留接口）
 *
 * 课程创新点预留模块：传入数据库表结构 Schema 与用户中文需求，
 * 由 DeepSeek 大模型生成合规 MySQL 查询语句，再执行并返回结果。
 * 此处仅预留调用接口，实际接入时补充 API Key 与 HTTP 调用逻辑。
 */
@Component
public class DeepSeekClient {

    /** DeepSeek API Key（部署时配置） */
    private static final String API_KEY = "your-deepseek-api-key";

    /** 接口地址 */
    private static final String API_URL = "https://api.deepseek.com/chat/completions";

    /**
     * 自然语言转 SQL（预留，未实现）
     *
     * @param question 用户中文需求，如"统计本月每个供应商的总供货金额"
     * @return 生成的 MySQL 查询语句
     */
    public String naturalLanguageToSql(String question) {
        // TODO: 调用 DeepSeek API（deepseek-reasoner 模型），
        //       传入表结构 Schema + question，返回 SQL 字符串
        throw new UnsupportedOperationException("DeepSeek 自然语言转 SQL 模块待接入");
    }
}
