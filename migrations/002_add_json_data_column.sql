-- =====================================================
-- 迁移脚本：添加 json_data 列到 ocr_results 表
-- 数据库: paddleocr_api
-- =====================================================

USE paddleocr_api;

-- 添加 json_data 列到 ocr_results 表
ALTER TABLE ocr_results
ADD COLUMN json_data JSON DEFAULT NULL COMMENT 'OCR识别JSON数据（包含box坐标、置信度等详细信息）'
AFTER raw_text;

-- 删除 genealogy_data 表（如果存在）
DROP TABLE IF EXISTS genealogy_data;

-- 删除 exports 表中的 include_structured 列（如果存在）
ALTER TABLE exports
DROP COLUMN IF EXISTS include_structured;

SELECT '迁移完成！json_data 列已添加，genealogy_data 表已删除' AS 状态;
