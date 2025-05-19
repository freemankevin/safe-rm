# safe-rm

## 项目介绍
safe-rm 是一个增强的文件删除工具，旨在防止危险的 rm 命令误删系统关键文件。它通过拦截和验证删除操作，保护系统免受意外或恶意的文件删除。

### 主要特性
- 防止删除根目录（/）及其直接内容
- 保护系统关键目录（/bin、/etc、/usr 等）
- 对数据目录（/root、/home、/data 等）进行特权控制
- 详细的操作日志记录
- 彩色输出和友好的提示信息

## 安装说明

### 系统要求
- Linux 系统
- root 权限（用于安装）

### 安装步骤
1. 下载最新版本的安装包：
   ```bash
   wget https://github.com/freemankevin/safe-rm/archive/main.tar.gz
   ```

2. 解压安装包：
   ```bash
   tar xf safe-rm.tar.gz
   ```

3. 运行安装脚本：
   ```bash
   sudo bash install.sh
   ```

### 卸载方法
```bash
sudo bash install.sh --uninstall
```

## 使用说明

### 基本用法
safe-rm 完全兼容原生 rm 命令的语法：

```bash
rm [选项]... [文件]...
```

### 常用选项
- `-f, --force`: 强制删除文件，忽略不存在的文件
- `-r, -R, --recursive`: 递归删除目录及其内容
- `-i`: 每次删除前提示
- `-v, --verbose`: 显示详细操作信息

### 特权选项
- `--force`: 允许删除数据目录
- `--verify=true`: 确认删除操作
- `--user=root`: 以root用户身份执行（仅用于特定目录）

### 使用示例
1. 删除普通文件：
   ```bash
   rm file.txt
   ```

2. 递归删除目录：
   ```bash
   rm -rf /home/user/test
   ```

3. 删除数据目录（需要特权）：
   ```bash
   rm -rf /data/ --force --verify=true
   ```

## 安全特性

### 保护机制
1. 系统关键目录保护
   - 防止删除系统运行必需的目录
   - 阻止在根目录使用通配符

2. 数据目录保护
   - 需要特权选项才能删除重要数据目录
   - 可配置自定义保护目录

3. 操作日志
   - 记录所有删除操作
   - 日志位置：/var/log/rm_protect.log

### 注意事项
- 某些操作可能需要 root 权限
- 建议定期检查日志文件
- 重要数据建议先备份再删除

## 贡献指南
欢迎提交问题报告和改进建议！请访问我们的 GitHub 仓库参与项目开发。

## 许可证
本项目采用 Apache-2.0 许可证 - 详见 [LICENSE](LICENSE) 文件