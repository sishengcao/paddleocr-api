-- ===================================================================
-- PaddleOCR API 数据库初始化脚本
-- 此脚本在容器首次启动时自动执行
-- ===================================================================

-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS paddleocr_api CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 使用数据库
USE paddleocr_api;

-- ===================================================================
-- 书籍表
-- ===================================================================
CREATE TABLE IF NOT EXISTS books (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    title VARCHAR(255) NOT NULL COMMENT '书籍标题',
    author VARCHAR(100) DEFAULT NULL COMMENT '作者',
    description TEXT DEFAULT NULL COMMENT '描述',
    total_pages INT UNSIGNED DEFAULT 0 COMMENT '总页数',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    INDEX idx_title (title),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='书籍信息表';

-- ===================================================================
-- 批量任务表
-- ===================================================================
CREATE TABLE IF NOT EXISTS batch_tasks (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    book_id INT UNSIGNED DEFAULT NULL COMMENT '书籍ID',
    task_type ENUM('scan', 'process', 'export') DEFAULT 'scan' COMMENT '任务类型',
    input_directory VARCHAR(500) DEFAULT NULL COMMENT '输入目录路径',
    file_count INT UNSIGNED DEFAULT 0 COMMENT '文件数量',
    status ENUM('pending', 'running', 'completed', 'failed', 'cancelled') DEFAULT 'pending' COMMENT '任务状态',
    progress INT UNSIGNED DEFAULT 0 COMMENT '进度百分比',
    processed_files INT UNSIGNED DEFAULT 0 COMMENT '已处理文件数',
    failed_files INT UNSIGNED DEFAULT 0 COMMENT '失败文件数',
    recursives TINYINT(1) DEFAULT 0 COMMENT '是否递归扫描',
    priority INT DEFAULT 5 COMMENT '任务优先级 (1-10, 10最高)',
    error_message TEXT DEFAULT NULL COMMENT '错误信息',
    result_directory VARCHAR(500) DEFAULT NULL COMMENT '结果目录',
    started_at TIMESTAMP NULL DEFAULT NULL COMMENT '开始时间',
    completed_at TIMESTAMP NULL DEFAULT NULL COMMENT '完成时间',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    INDEX idx_book_id (book_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    INDEX idx_priority (priority),
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='批量任务表';

-- ===================================================================
-- OCR 结果表
-- ===================================================================
CREATE TABLE IF NOT EXISTS ocr_results (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    task_id INT UNSIGNED DEFAULT NULL COMMENT '任务ID',
    book_id INT UNSIGNED DEFAULT NULL COMMENT '书籍ID',

    -- 核心字段（用户要求）
    file_name VARCHAR(255) NOT NULL COMMENT '文件名',
    page_number INT UNSIGNED DEFAULT NULL COMMENT '页码',
    raw_text LONGTEXT DEFAULT NULL COMMENT 'OCR识别后的文字',
    json_data JSON DEFAULT NULL COMMENT 'OCR识别JSON数据（包含box坐标、置信度等详细信息）',

    -- 辅助字段（功能需要）
    volume VARCHAR(100) DEFAULT NULL COMMENT '卷号',
    confidence DECIMAL(5, 4) DEFAULT 0.0000 COMMENT '识别置信度',
    success TINYINT(1) DEFAULT 1 COMMENT '识别成功状态 (0失败 1成功)',
    processing_time DECIMAL(10, 3) DEFAULT 0.000 COMMENT '处理时间（秒）',

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    INDEX idx_task_id (task_id),
    INDEX idx_book_id (book_id),
    INDEX idx_file_name (file_name),
    INDEX idx_page_number (page_number),
    INDEX idx_volume (volume),
    INDEX idx_success (success),
    INDEX idx_created_at (created_at),
    FULLTEXT idx_raw_text (raw_text),
    FOREIGN KEY (task_id) REFERENCES batch_tasks(id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OCR识别结果表';

-- ===================================================================
-- 导出记录表
-- ===================================================================
CREATE TABLE IF NOT EXISTS exports (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    task_id INT UNSIGNED NOT NULL COMMENT '任务ID',
    export_type ENUM('json', 'csv', 'excel') DEFAULT 'json' COMMENT '导出类型',
    file_path VARCHAR(500) DEFAULT NULL COMMENT '导出文件路径',
    file_size BIGINT UNSIGNED DEFAULT 0 COMMENT '文件大小（字节）',
    status ENUM('pending', 'completed', 'failed') DEFAULT 'pending' COMMENT '导出状态',
    error_message TEXT DEFAULT NULL COMMENT '错误信息',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    completed_at TIMESTAMP NULL DEFAULT NULL COMMENT '完成时间',
    INDEX idx_task_id (task_id),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at),
    FOREIGN KEY (task_id) REFERENCES batch_tasks(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='导出记录表';

-- ===================================================================
-- 插入示例数据（可选）
-- ===================================================================

-- 插入示例书籍
INSERT INTO books (title, author, description, total_pages) VALUES
('示例族谱-第一卷', '佚名', '这是一本示例族谱', 100)
ON DUPLICATE KEY UPDATE title=title;

-- ===================================================================
-- 创建视图：任务统计
-- ===================================================================
CREATE OR REPLACE VIEW v_task_stats AS
SELECT
    bt.id AS task_id,
    bt.status,
    bt.file_count,
    bt.processed_files,
    bt.failed_files,
    bt.progress,
    COUNT(DISTINCT or.id) AS ocr_result_count,
    b.title AS book_title,
    bt.created_at
FROM batch_tasks bt
LEFT JOIN books b ON bt.book_id = b.id
LEFT JOIN ocr_results or ON bt.id = or.task_id
GROUP BY bt.id;

-- ===================================================================
-- 完成
-- ===================================================================
