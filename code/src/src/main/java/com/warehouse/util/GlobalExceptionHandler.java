package com.warehouse.util;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

/**
 * 全局异常处理器：将数据库异常（外键约束等）转成友好提示
 */
@ControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(DataIntegrityViolationException.class)
    public String handleDataIntegrity(DataIntegrityViolationException e, Model model) {
        model.addAttribute("error", "操作失败：该数据已被其他业务数据引用，或关联了不存在的数据，无法执行该操作。");
        return "error";
    }

    @ExceptionHandler(Exception.class)
    public String handleException(Exception e, Model model) {
        model.addAttribute("error", "系统异常：" + e.getMessage());
        return "error";
    }
}
