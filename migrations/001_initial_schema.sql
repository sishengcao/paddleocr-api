-- =====================================================
-- PaddleOCR API 数据库架构
-- 数据库: paddleocr_api
-- =====================================================

CREATE DATABASE IF NOT EXISTS paddleocr_api
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE paddleocr_api;

-- =====================================================
-- 1. 书籍元数据表
-- =====================================================
CREATE TABLE books (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    book_id VARCHAR(255) NOT NULL UNIQUE COMMENT '书籍标识符',
    title VARCHAR(500) DEFAULT NULL COMMENT '书籍标题',
    author VARCHAR(255) DEFAULT NULL COMMENT '作者',
    category VARCHAR(100) DEFAULT NULL COMMENT '分类（族谱、文学等）',
    description TEXT DEFAULT NULL COMMENT '书籍描述',
    source_directory VARCHAR(1000) DEFAULT NULL COMMENT '源目录路径',
    total_pages INT UNSIGNED DEFAULT 0 COMMENT '总页数',
    total_volumes INT UNSIGNED DEFAULT 0 COMMENT '总卷数',
    metadata JSON DEFAULT NULL COMMENT '额外元数据（JSON格式）',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    INDEX idx_book_id (book_id),
    INDEX idx_category (category),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='书籍元数据表';

-- =====================================================
-- 2. 批量扫描任务表
-- =====================================================
CREATE TABLE batch_tasks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    task_id VARCHAR(36) NOT NULL UNIQUE COMMENT '任务UUID标识符',
    book_id VARCHAR(255) NOT NULL COMMENT '关联书籍ID',
    task_name VARCHAR(500) DEFAULT NULL COMMENT '任务名称/描述',
    source_directory VARCHAR(1000) NOT NULL COMMENT '源目录路径',

    -- 任务配置
    lang VARCHAR(10) DEFAULT 'ch' COMMENT 'OCR识别语言',
    use_angle_cls TINYINT DEFAULT 1 COMMENT '是否使用角度分类',
    text_layout VARCHAR(20) DEFAULT 'horizontal' COMMENT '文字排版方向',
    output_format VARCHAR(30) DEFAULT 'line_by_line' COMMENT '输出格式',
    recursives TINYINT DEFAULT 1 COMMENT '是否递归扫描目录',
    file_patterns JSON DEFAULT NULL COMMENT '文件匹配模式',

    -- 任务状态
    status ENUM('pending', 'queued', 'processing', 'completed', 'failed', 'cancelled', 'retrying')
        DEFAULT 'pending' COMMENT '任务状态',
    priority INT DEFAULT 5 COMMENT '任务优先级（1-10，数字越大优先级越高）',

    -- 统计信息
    total_files INT UNSIGNED DEFAULT 0 COMMENT '待处理文件总数',
    processed_files INT UNSIGNED DEFAULT 0 COMMENT '已处理文件数',
    success_files INT UNSIGNED DEFAULT 0 COMMENT '成功处理文件数',
    failed_files INT UNSIGNED DEFAULT 0 COMMENT '失败处理文件数',
    progress DECIMAL(5,2) DEFAULT 0.00 COMMENT '进度百分比',

    -- Celery任务追踪
    celery_task_id VARCHAR(255) DEFAULT NULL COMMENT 'Celery任务ID',
    worker_name VARCHAR(255) DEFAULT NULL COMMENT '处理的Worker名称',
    retry_count INT UNSIGNED DEFAULT 0 COMMENT '重试次数',
    max_retries INT UNSIGNED DEFAULT 3 COMMENT '最大重试次数',

    -- 时间戳
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    queued_at TIMESTAMP NULL DEFAULT NULL COMMENT '排队时间',
    started_at TIMESTAMP NULL DEFAULT NULL COMMENT '开始时间',
    completed_at TIMESTAMP NULL DEFAULT NULL COMMENT '完成时间',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',

    -- 错误追踪
    error_message TEXT DEFAULT NULL COMMENT '失败时的错误消息',
    error_stack TEXT DEFAULT NULL COMMENT '完整错误堆栈',

    -- 重复检测
    task_hash VARCHAR(64) DEFAULT NULL COMMENT '任务哈希值（目录+配置）用于重复检测',

    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    INDEX idx_task_id (task_id),
    INDEX idx_book_id (book_id),
    INDEX idx_status (status),
    INDEX idx_priority (priority),
    INDEX idx_created_at (created_at),
    INDEX idx_task_hash (task_hash),
    INDEX idx_celery_task_id (celery_task_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='批量扫描任务表';

-- =====================================================
-- 3. OCR识别结果表（简化版）
-- =====================================================
-- 简化说明：只存储用户要求的核心字段 + 运行必需的辅助字段
-- 核心字段：file_name (文件名)、page_number (页码)、raw_text (识别后的文字)
-- 辅助字段：volume (卷号)、confidence (置信度)、success (状态)、processing_time (处理时间)
CREATE TABLE ocr_results (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    task_id VARCHAR(36) NOT NULL COMMENT '关联任务ID',
    book_id VARCHAR(255) NOT NULL COMMENT '关联书籍ID',
    page_id VARCHAR(36) NOT NULL UNIQUE COMMENT '页面唯一标识符',

    -- 核心字段（用户要求）
    file_name VARCHAR(255) NOT NULL COMMENT '文件名',
    page_number INT UNSIGNED DEFAULT NULL COMMENT '页码',
    raw_text LONGTEXT DEFAULT NULL COMMENT 'OCR识别后的文字',
    json_data JSON DEFAULT NULL COMMENT 'OCR识别JSON数据（包含box坐标、置信度等详细信息）',

    -- 辅助字段（项目运行必需）
    volume VARCHAR(100) DEFAULT NULL COMMENT '卷号',
    confidence DECIMAL(5,4) DEFAULT 0.0000 COMMENT '识别置信度',
    success TINYINT DEFAULT 1 COMMENT '识别成功状态',
    processing_time DECIMAL(10,3) DEFAULT 0.000 COMMENT '处理时间（秒）',

    -- 时间戳
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    FOREIGN KEY (task_id) REFERENCES batch_tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    INDEX idx_task_id (task_id),
    INDEX idx_book_id (book_id),
    INDEX idx_page_id (page_id),
    INDEX idx_page_number (page_number),
    INDEX idx_volume (volume),
    INDEX idx_success (success),
    INDEX idx_confidence (confidence),
    INDEX idx_book_page (book_id, page_number),
    FULLTEXT INDEX ft_raw_text (raw_text) WITH PARSER ngram
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='OCR识别结果表（简化版）';

-- =====================================================
-- 4. 导出记录表
-- =====================================================
CREATE TABLE exports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    export_id VARCHAR(36) NOT NULL UNIQUE COMMENT '导出任务UUID',
    task_id VARCHAR(36) NOT NULL COMMENT '来源任务ID',
    book_id VARCHAR(255) NOT NULL COMMENT '来源书籍ID',

    -- 导出配置
    export_format ENUM('json', 'csv', 'excel', 'xml') DEFAULT 'json' COMMENT '导出格式',
    include_images TINYINT DEFAULT 0 COMMENT '是否包含图片引用',
    include_details TINYINT DEFAULT 0 COMMENT '是否包含详细OCR数据',

    -- 导出状态
    status ENUM('pending', 'processing', 'completed', 'failed') DEFAULT 'pending' COMMENT '导出状态',
    progress DECIMAL(5,2) DEFAULT 0.00 COMMENT '导出进度',

    -- 文件信息
    file_path VARCHAR(1000) DEFAULT NULL COMMENT '导出文件路径',
    file_size BIGINT UNSIGNED DEFAULT 0 COMMENT '文件大小（字节）',
    file_count INT UNSIGNED DEFAULT 0 COMMENT '创建的文件数量',
    download_url VARCHAR(1000) DEFAULT NULL COMMENT '下载链接',

    -- 过期
    expires_at TIMESTAMP NULL DEFAULT NULL COMMENT '导出文件过期时间',

    -- 统计
    total_records INT UNSIGNED DEFAULT 0 COMMENT '导出的记录总数',

    -- 时间戳
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    completed_at TIMESTAMP NULL DEFAULT NULL COMMENT '完成时间',

    FOREIGN KEY (task_id) REFERENCES batch_tasks(task_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES books(book_id) ON DELETE CASCADE,
    INDEX idx_export_id (export_id),
    INDEX idx_task_id (task_id),
    INDEX idx_book_id (book_id),
    INDEX idx_status (status),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='导出记录表';

-- =====================================================
-- 6. 任务锁表（防重复）
-- =====================================================
CREATE TABLE task_locks (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    lock_key VARCHAR(255) NOT NULL UNIQUE COMMENT '锁键值（目录+配置的哈希）',
    task_id VARCHAR(36) NOT NULL COMMENT '关联任务ID',
    book_id VARCHAR(255) NOT NULL COMMENT '关联书籍ID',
    status ENUM('active', 'completed', 'expired') DEFAULT 'active' COMMENT '锁状态',
    locked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '锁定时间',
    expires_at TIMESTAMP NOT NULL COMMENT '锁过期时间',

    INDEX idx_lock_key (lock_key),
    INDEX idx_status (status),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='任务锁表（防重复）';

-- =====================================================
-- 7. 处理日志表
-- =====================================================
CREATE TABLE processing_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID',
    task_id VARCHAR(36) NOT NULL COMMENT '关联任务ID',
    page_id VARCHAR(36) DEFAULT NULL COMMENT '关联页面ID',

    -- 日志信息
    log_level ENUM('DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL') DEFAULT 'INFO' COMMENT '日志级别',
    message TEXT NOT NULL COMMENT '日志消息',
    module VARCHAR(255) DEFAULT NULL COMMENT '模块名',
    function_name VARCHAR(255) DEFAULT NULL COMMENT '函数名',
    line_number INT DEFAULT NULL COMMENT '行号',

    -- 上下文
    context JSON DEFAULT NULL COMMENT '额外上下文数据',

    -- 时间戳
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',

    FOREIGN KEY (task_id) REFERENCES batch_tasks(task_id) ON DELETE CASCADE,
    INDEX idx_task_id (task_id),
    INDEX idx_log_level (log_level),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='处理日志表';

-- =====================================================
-- 常用查询视图
-- =====================================================

-- 视图：任务摘要
CREATE VIEW v_task_summary AS
SELECT
    bt.task_id AS 任务ID,
    bt.book_id AS 书籍ID,
    b.title AS 书名,
    bt.status AS 状态,
    bt.progress AS 进度,
    bt.total_files AS 总文件数,
    bt.processed_files AS 已处理数,
    bt.success_files AS 成功数,
    bt.failed_files AS 失败数,
    bt.created_at AS 创建时间,
    bt.started_at AS 开始时间,
    bt.completed_at AS 完成时间,
    TIMESTAMPDIFF(SECOND, bt.started_at, bt.completed_at) AS 耗时秒数
FROM batch_tasks bt
LEFT JOIN books b ON bt.book_id = b.book_id;

-- 视图：书籍统计
CREATE VIEW v_book_statistics AS
SELECT
    b.book_id AS 书籍ID,
    b.title AS 书名,
    b.category AS 分类,
    COUNT(DISTINCT bt.task_id) AS 总任务数,
    SUM(bt.total_files) AS 总页数,
    SUM(CASE WHEN bt.status = 'completed' THEN 1 ELSE 0 END) AS 已完成任务数,
    SUM(CASE WHEN bt.status = 'processing' THEN 1 ELSE 0 END) AS 处理中任务数,
    MIN(bt.created_at) AS 首次扫描时间,
    MAX(bt.completed_at) AS 最后扫描时间
FROM books b
LEFT JOIN batch_tasks bt ON b.book_id = bt.book_id
GROUP BY b.book_id, b.title, b.category;

-- =====================================================
-- 初始化完成
-- =====================================================
SELECT '数据库架构初始化完成！' AS 状态;
