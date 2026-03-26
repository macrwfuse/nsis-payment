@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo   付费启动器 - 美化版打包脚本
echo ========================================
echo.

:: 检查 makensis
where makensis >nul 2>&1
if %errorlevel% neq 0 (
    echo [错误] 未找到 makensis，请先安装 NSIS
    echo 下载: https://nsis.sourceforge.io/Download
    pause
    exit /b 1
)

:: 检查目标程序
if not exist "run.exe" (
    echo [错误] 未找到目标程序 run.exe
    echo 请将你的程序命名为 run.exe 放在当前目录
    pause
    exit /b 1
)

:: 检查/生成资源
echo [1/4] 检查 UI 资源...
if not exist "assets\header_bg.bmp" (
    echo [提示] 正在生成 UI 资源...
    python3 scripts\gen_assets.py
    if %errorlevel% neq 0 (
        echo [提示] 需要 Python + Pillow 来生成资源
        echo 运行: pip install Pillow
        echo 然后: python3 scripts\gen_assets.py
    )
)

:: 检查 curl
echo [2/4] 检查 curl...
if not exist "assets\curl.exe" (
    where curl >nul 2>&1
    if %errorlevel% equ 0 (
        copy "%SystemRoot%\System32\curl.exe" "assets\curl.exe" >nul 2>&1
        echo [√] 已复制系统 curl
    ) else (
        echo [!] 需要将 curl.exe 放入 assets\ 目录
        echo 下载: https://curl.se/windows/
        pause
        exit /b 1
    )
)

:: 编译
echo [3/4] 编译 NSIS 脚本...
makensis /V2 PayLauncher.nsi
if %errorlevel% neq 0 (
    echo [×] 编译失败
    pause
    exit /b 1
)

echo [4/4] 清理临时文件...
echo.
echo ========================================
echo   [√] 编译成功！
echo   输出: PayLauncher.exe
echo ========================================
echo.
echo 下一步:
echo   1. 启动后端:  cd backend ^&^& npm start
echo   2. 修改 PayLauncher.nsi 中 PayApiUrl 为你的服务器地址
echo   3. Demo 测试: PAYMENT_MODE=demo node server.js
echo.
pause
