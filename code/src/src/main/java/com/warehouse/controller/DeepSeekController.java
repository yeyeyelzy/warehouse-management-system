package com.warehouse.controller;

import com.warehouse.util.DeepSeekClient;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * DeepSeek 自然语言转 SQL 预留接口
 */
@RestController
public class DeepSeekController {

    private final DeepSeekClient deepSeekClient;

    public DeepSeekController(DeepSeekClient deepSeekClient) {
        this.deepSeekClient = deepSeekClient;
    }

    /**
     * 预留接口：输入中文需求，返回 SQL（待接入 DeepSeek API）
     */
    @PostMapping("/api/deepseek/query")
    public Map<String, Object> query(@RequestBody Map<String, String> body) {
        String question = body.getOrDefault("question", "");
        Map<String, Object> result = new HashMap<>();
        try {
            String sql = deepSeekClient.naturalLanguageToSql(question);
            result.put("success", true);
            result.put("sql", sql);
        } catch (UnsupportedOperationException e) {
            result.put("success", false);
            result.put("message", e.getMessage());
        }
        return result;
    }
}
