# FinalizeAndArchiveProject

高性能项目归档处理工具

## Description

此模块用于自动化完成项目的最终归档流程，包括：

- 项目选择
- 文件整理与重命名
- 警告图片插入
- README 更新
- 项目备份与归档

## Requirements

- PowerShell 7.0+
- PSToml module

## Installation

```powershell
Install-Module -Name PSToml -Repository PSGallery -Scope CurrentUser
```

## Usage

```powershell
Import-Module FinalizeAndArchiveProject
Start-FinalizeAndArchive
```

## Configuration

配置文件 `config.toml` 需要包含以下内容：

```toml
[paths]
active_dir = "D:\\path\\to\\active\\projects"
archive_dir = "D:\\path\\to\\archive\\completed"
warning_image = "D:\\path\\to\\warning_image.webp"

[settings]
image_extensions = [".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp"]
```

## License

MIT
