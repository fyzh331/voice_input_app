#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
一键安装 Flutter（国内镜像加速版）
修复：正确的解压路径和 Android SDK 下载地址
"""

import os
import sys
import platform
import subprocess
import zipfile
import tarfile
import shutil
import urllib.request
import ssl
from pathlib import Path

# ================== 配置 ==================
# Flutter SDK 下载地址（使用国内镜像）
FLUTTER_SDK_URLS = {
    "windows": {
        "stable": "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.3-stable.zip",
        "beta": "https://storage.flutter-io.cn/flutter_infra_release/releases/beta/windows/flutter_windows_3.27.0-beta.zip",
    },
    "macos": {
        "stable": "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.3-stable.zip",
        "beta": "https://storage.flutter-io.cn/flutter_infra_release/releases/beta/macos/flutter_macos_3.27.0-beta.zip",
    },
    "linux": {
        "stable": "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.3-stable.tar.xz",
        "beta": "https://storage.flutter-io.cn/flutter_infra_release/releases/beta/linux/flutter_linux_3.27.0-beta.tar.xz",
    },
}

# Android SDK 下载地址（修复 404）
ANDROID_SDK_URLS = {
    "windows": {
        "latest": "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip",
        "backup": "https://mirrors.aliyun.com/android/repository/commandlinetools-win-11076708_latest.zip",
    },
    "macos": {
        "latest": "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip",
        "backup": "https://mirrors.aliyun.com/android/repository/commandlinetools-mac-11076708_latest.zip",
    },
    "linux": {
        "latest": "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip",
        "backup": "https://mirrors.aliyun.com/android/repository/commandlinetools-linux-11076708_latest.zip",
    },
}

# Python 国内镜像源
PIP_MIRRORS = {
    "tsinghua": "https://pypi.tuna.tsinghua.edu.cn/simple",
    "aliyun": "https://mirrors.aliyun.com/pypi/simple/",
    "tencent": "https://mirrors.cloud.tencent.com/pypi/simple",
}

# ================== 颜色输出 ==================
class Colors:
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

def print_color(text, color=Colors.RESET):
    print(f"{color}{text}{Colors.RESET}")

def print_step(step, text):
    print_color(f"\n[{step}] {text}", Colors.CYAN + Colors.BOLD)

def print_success(text):
    print_color(f"✅ {text}", Colors.GREEN)

def print_error(text):
    print_color(f"❌ {text}", Colors.RED)

def print_warning(text):
    print_color(f"⚠️ {text}", Colors.YELLOW)

def print_info(text):
    print_color(f"ℹ️ {text}", Colors.BLUE)

# ================== 系统检测 ==================
def get_system():
    system = platform.system().lower()
    if system == 'windows':
        return 'windows'
    elif system == 'darwin':
        return 'macos'
    elif system == 'linux':
        return 'linux'
    else:
        print_error(f"不支持的操作系统: {system}")
        sys.exit(1)

# ================== 下载工具 ==================
def download_file(url, dest_path, show_progress=True):
    """下载文件并显示进度"""
    try:
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE
        
        print_info(f"下载: {url}")
        
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        
        with urllib.request.urlopen(req, context=ssl_context, timeout=60) as response:
            total_size = int(response.headers.get('content-length', 0))
            downloaded = 0
            chunk_size = 8192
            
            with open(dest_path, 'wb') as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    if show_progress and total_size > 0:
                        percent = downloaded / total_size * 100
                        bar_length = 40
                        filled = int(bar_length * downloaded / total_size)
                        bar = '█' * filled + '░' * (bar_length - filled)
                        sys.stdout.write(f'\r  进度: |{bar}| {percent:.1f}%')
                        sys.stdout.flush()
            
            if show_progress:
                sys.stdout.write('\n')
        
        return True
    
    except Exception as e:
        print_error(f"下载失败: {e}")
        return False

def extract_zip(zip_path, extract_to):
    """解压 ZIP 文件"""
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_to)
        return True
    except Exception as e:
        print_error(f"解压失败: {e}")
        return False

# ================== Flutter 安装 ==================
def install_flutter():
    print_color("\n" + "="*60, Colors.BOLD + Colors.MAGENTA)
    print_color("          Flutter 一键安装脚本 (国内镜像加速)", Colors.BOLD + Colors.MAGENTA)
    print_color("="*60, Colors.BOLD + Colors.MAGENTA)
    
    system = get_system()
    print_info(f"检测到系统: {system}")
    
    # 选择安装目录
    default_install_path = os.path.expanduser("~/flutter")
    print_info(f"默认安装目录: {default_install_path}")
    install_path = input(f"\n请输入安装目录 [回车使用默认]: ").strip()
    if not install_path:
        install_path = default_install_path
    
    # 选择 Flutter 版本
    print_step("1", "选择 Flutter 版本")
    print("   1. stable (稳定版，推荐)")
    print("   2. beta (测试版)")
    
    version_choice = input("请选择 [1/2]: ").strip()
    version = "beta" if version_choice == "2" else "stable"
    
    # 获取下载链接
    sdk_url = FLUTTER_SDK_URLS.get(system, {}).get(version)
    if not sdk_url:
        print_error(f"不支持的系统或版本")
        sys.exit(1)
    
    print_info(f"将下载版本: {version}")
    print_info(f"下载地址: {sdk_url}")
    
    # 创建安装目录
    os.makedirs(install_path, exist_ok=True)
    
    # 下载 Flutter SDK
    print_step("2", "下载 Flutter SDK")
    
    temp_file = os.path.join(install_path, f"flutter_temp{'zip' if system == 'windows' else 'tar.xz'}")
    
    if not download_file(sdk_url, temp_file):
        print_error("下载失败，请检查网络连接")
        sys.exit(1)
    
    print_success(f"下载完成: {temp_file}")
    
    # 解压 SDK
    print_step("3", "解压 Flutter SDK")
    
    if system == 'windows':
        success = extract_zip(temp_file, install_path)
    else:
        # Linux/Mac 需要安装 tarfile 支持
        try:
            with tarfile.open(temp_file, 'r:xz') as tar:
                tar.extractall(install_path)
            success = True
        except Exception as e:
            print_error(f"解压失败: {e}")
            success = False
    
    if not success:
        print_error("解压失败")
        sys.exit(1)
    
    # 清理临时文件
    os.remove(temp_file)
    
    # 查找 Flutter 目录（解压后的目录名可能是 flutter）
    flutter_dir = None
    for item in os.listdir(install_path):
        item_path = os.path.join(install_path, item)
        if os.path.isdir(item_path) and item.lower().startswith('flutter'):
            flutter_dir = item_path
            break
    
    if not flutter_dir:
        # 尝试直接使用安装路径
        flutter_dir = os.path.join(install_path, 'flutter')
    
    flutter_bin = os.path.join(flutter_dir, 'bin')
    flutter_exe = os.path.join(flutter_bin, 'flutter.exe' if system == 'windows' else 'flutter')
    
    print_success(f"Flutter 已安装到: {flutter_dir}")
    
    # 验证 flutter.exe 是否存在
    if not os.path.exists(flutter_exe):
        print_error(f"找不到 flutter 可执行文件: {flutter_exe}")
        print_info("尝试查找正确的位置...")
        
        # 递归查找 flutter.exe
        for root, dirs, files in os.walk(install_path):
            if 'flutter.exe' in files and system == 'windows':
                flutter_exe = os.path.join(root, 'flutter.exe')
                flutter_bin = root
                flutter_dir = os.path.dirname(root)
                print_success(f"找到: {flutter_exe}")
                break
            elif 'flutter' in files and not system == 'windows':
                flutter_exe = os.path.join(root, 'flutter')
                flutter_bin = root
                flutter_dir = os.path.dirname(root)
                print_success(f"找到: {flutter_exe}")
                break
    
    # 配置环境变量
    print_step("4", "配置环境变量")
    
    # 创建环境设置脚本
    if system == 'windows':
        set_bat = os.path.join(flutter_dir, 'set_flutter_env.bat')
        with open(set_bat, 'w', encoding='utf-8') as f:
            f.write(f'@echo off\n')
            f.write(f'echo 设置 Flutter 环境变量...\n')
            f.write(f'set PATH={flutter_bin};%PATH%\n')
            f.write(f'set PUB_HOSTED_URL=https://pub.flutter-io.cn\n')
            f.write(f'set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn\n')
            f.write(f'echo 环境变量已设置\n')
            f.write(f'echo.\n')
            f.write(f'echo 当前 Flutter 版本：\n')
            f.write(f'{flutter_exe} --version\n')
        print_success(f"已创建环境设置脚本: {set_bat}")
        print_info("每次使用前请运行: set_flutter_env.bat")
    else:
        # 写入 shell 配置文件
        shell_rc = os.path.expanduser("~/.zshrc") if os.path.exists(os.path.expanduser("~/.zshrc")) else os.path.expanduser("~/.bashrc")
        with open(shell_rc, 'a') as f:
            f.write(f'\n# Flutter 环境变量\n')
            f.write(f'export PATH="$PATH:{flutter_bin}"\n')
            f.write(f'export PUB_HOSTED_URL="https://pub.flutter-io.cn"\n')
            f.write(f'export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"\n')
        print_success(f"已添加到 {shell_rc}")
    
    # 配置国内镜像源（创建 flutter 配置）
    print_step("5", "配置国内镜像源")
    
    # 创建 flutter 配置目录
    flutter_config_dir = os.path.expanduser("~/.flutter")
    os.makedirs(flutter_config_dir, exist_ok=True)
    
    # 运行 flutter doctor
    print_step("6", "运行 flutter doctor")
    
    # 设置临时环境变量运行 flutter doctor
    env = os.environ.copy()
    env['PATH'] = flutter_bin + os.pathsep + env.get('PATH', '')
    env['PUB_HOSTED_URL'] = 'https://pub.flutter-io.cn'
    env['FLUTTER_STORAGE_BASE_URL'] = 'https://storage.flutter-io.cn'
    
    print_info("首次运行会下载 Dart SDK，请稍候...")
    
    try:
        result = subprocess.run(
            [flutter_exe, 'doctor', '--version'],
            env=env,
            capture_output=True,
            text=True,
            timeout=120
        )
        if result.returncode == 0:
            print_success(f"Flutter 版本: {result.stdout.strip()}")
        else:
            print_warning("flutter doctor 输出异常")
    except subprocess.TimeoutExpired:
        print_warning("flutter doctor 执行超时")
    except Exception as e:
        print_warning(f"flutter doctor 执行失败: {e}")
    
    # 安装 Android SDK（可选）
    print_step("7", "安装 Android SDK（可选，用于打包 APK）")
    install_android = input("\n是否安装 Android SDK 命令行工具？[y/N]: ").strip().lower()
    
    if install_android == 'y':
        install_android_sdk(system)
    
    # 安装 Python 依赖
    print_step("8", "安装 Python 依赖（用于辅助功能）")
    install_python_deps()
    
    # 完成
    print_color("\n" + "="*60, Colors.BOLD + Colors.GREEN)
    print_color("              Flutter 安装完成！", Colors.BOLD + Colors.GREEN)
    print_color("="*60, Colors.BOLD + Colors.GREEN)
    
    print_info("\n下一步：")
    print_info("1. 打开新的命令行窗口")
    if system == 'windows':
        print_info(f"2. 运行: {set_bat}")
    else:
        print_info(f"2. 运行: source ~/.zshrc 或 source ~/.bashrc")
    print_info("3. 运行 flutter doctor 检查环境")
    print_info("4. 如需打包安卓 APK，请安装 Android Studio")
    print_info("\n快速测试：")
    if system == 'windows':
        print_info(f"   cd {flutter_dir}\\examples\\hello_world")
    else:
        print_info(f"   cd {flutter_dir}/examples/hello_world")
    print_info("   flutter run")

def install_android_sdk(system):
    """安装 Android SDK 命令行工具"""
    print_info("下载 Android SDK 命令行工具...")
    
    sdk_info = ANDROID_SDK_URLS.get(system, {}).get('latest')
    backup_url = ANDROID_SDK_URLS.get(system, {}).get('backup')
    
    if not sdk_info:
        print_error(f"不支持的系统: {system}")
        return
    
    android_home = os.path.expanduser("~/Android/Sdk")
    os.makedirs(android_home, exist_ok=True)
    
    temp_zip = os.path.join(android_home, "cmdline-tools.zip")
    
    # 尝试下载
    success = download_file(sdk_info, temp_zip)
    
    if not success and backup_url:
        print_warning("使用备用镜像下载...")
        success = download_file(backup_url, temp_zip)
    
    if success:
        # 解压
        extract_zip(temp_zip, android_home)
        os.remove(temp_zip)
        
        # 重命名 cmdline-tools 目录
        cmdline_src = os.path.join(android_home, 'cmdline-tools')
        if os.path.exists(cmdline_src):
            # 创建正确的目录结构
            tools_dir = os.path.join(android_home, 'cmdline-tools', 'tools')
            os.makedirs(tools_dir, exist_ok=True)
            
            # 移动文件
            for item in os.listdir(cmdline_src):
                if item != 'tools':
                    src = os.path.join(cmdline_src, item)
                    dst = os.path.join(tools_dir, item)
                    if os.path.exists(src):
                        shutil.move(src, dst)
        
        # 设置环境变量提示
        print_success("Android SDK 命令行工具安装完成")
        print_info(f"Android SDK 路径: {android_home}")
        
        # 添加环境变量
        if system == 'windows':
            print_info("请手动添加以下环境变量：")
            print_color(f"   ANDROID_HOME={android_home}", Colors.YELLOW)
            print_color(f"   PATH=%ANDROID_HOME%\\cmdline-tools\\tools\\bin;%PATH%", Colors.YELLOW)
        else:
            shell_rc = os.path.expanduser("~/.zshrc") if os.path.exists(os.path.expanduser("~/.zshrc")) else os.path.expanduser("~/.bashrc")
            with open(shell_rc, 'a') as f:
                f.write(f'\n# Android SDK\n')
                f.write(f'export ANDROID_HOME={android_home}\n')
                f.write(f'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/tools/bin"\n')
            print_success(f"已添加 Android SDK 环境变量到 {shell_rc}")
    else:
        print_error("Android SDK 下载失败")
        print_info("您可以稍后手动下载：")
        print_info("https://developer.android.com/studio#command-line-tools-only")

def install_python_deps():
    """安装 Python 依赖"""
    print_info("安装 Python 依赖包...")
    
    # 选择镜像源
    print("\n请选择 Python 镜像源：")
    for i, (name, url) in enumerate(PIP_MIRRORS.items(), 1):
        print(f"   {i}. {name} ({url})")
    
    choice = input("请选择 [1/2/3，默认1]: ").strip()
    if choice.isdigit() and 1 <= int(choice) <= 3:
        mirror = list(PIP_MIRRORS.values())[int(choice)-1]
    else:
        mirror = PIP_MIRRORS["tsinghua"]
    
    packages = ["requests", "rich", "tqdm"]
    
    for package in packages:
        print_info(f"安装 {package}...")
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", package, "-i", mirror],
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print_warning(f"{package} 安装失败")
    
    print_success("Python 依赖安装完成")

# ================== 主函数 ==================
if __name__ == "__main__":
    try:
        install_flutter()
    except KeyboardInterrupt:
        print_warning("\n用户中断安装")
        sys.exit(0)
    except Exception as e:
        print_error(f"安装过程中发生错误: {e}")
        sys.exit(1)
