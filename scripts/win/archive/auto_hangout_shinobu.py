#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
久岐忍 5结局全自动邀约任务 + 采矿/钓鱼/材料收集 v6

v6更新:
- 每个结局最多3次尝试, 3次仍无法推进则放弃邀约, 记录失败原因, 直接跑一条龙
- 关键修复: JS用内置 genshin.Tp 传送到稻妻城锚点(解决卡在地图/不在任务现场)
  传送到奉行所附近后自动移动找上杉按F, 剧情选项交给BGI内置"实时触发-自动邀约"
- 读取errors.json显示已知错误, 避免重复犯错
- 邀约(无论成功或放弃)后自动跑: 采矿 → 钓鱼 → 伊安珊材料
- 监控ERROR_LOG日志输出, 每步错误详细记录

流程:
  杀BGI → 改配置 → 启动BGI(JS导航+监督) → 等待NAV_RESULT → 下一个结局
  → 全部结局后 → 采矿 → 钓鱼 → 伊安珊材料
"""

import ctypes
import ctypes.wintypes as wintypes
import json
import os
import sys
import time
import subprocess
import glob

# ===== BetterGI 路径 =====
BGI_DIR = r"D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0"
CONFIG_PATH = os.path.join(BGI_DIR, "User", "config.json")
EXE_PATH = os.path.join(BGI_DIR, "BetterGI.exe")
LOG_DIR = os.path.join(BGI_DIR, "log")
ERRORS_JSON = os.path.join(BGI_DIR, "User", "JsScript", "AutoHangoutShinobu", "errors.json")
SCRIPT_GROUP = "久岐忍邀约导航"

# 原神路径
GAME_PATH = r"e:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe"

# 每个结局最多尝试次数 (用户要求: 3次不能推进就放弃, 跑一条龙)
MAX_RETRY_PER_ENDING = 3

# 邀约后的任务组 (按顺序执行)
POST_HANGOUT_GROUPS = ["采矿", "钓鱼", "伊安珊材料"]

ENDINGS = [
    {"name": "久岐忍结局1:期待之外的工资", "branch": 0, "dialog": ["快步上前袒护", "道歉要紧", "姑且顺从她的意思吧"]},
    {"name": "久岐忍结局2:接下来是商务密谈", "branch": 3, "dialog": ["快步上前袒护", "道歉要紧", "千万不能被她带着走"]},
    {"name": "久岐忍结局3:法度执行", "branch": 2, "dialog": ["快步上前袒护", "让我来代劳", "还是跟我走吧"]},
    {"name": "久岐忍结局4:是祸躲不过", "branch": 3, "dialog": ["快步上前袒护", "让我来代劳", "我帮你藏好吧"]},
    {"name": "久岐忍结局5:荒泷派町街服务记录", "branch": 1, "dialog": ["默默退后半步"]},
]

# ===== Windows API =====
user32 = ctypes.windll.user32

def find_game_window():
    WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
    result = []

    class RECT(ctypes.Structure):
        _fields_ = [('left', wintypes.LONG), ('top', wintypes.LONG),
                    ('right', wintypes.LONG), ('bottom', wintypes.LONG)]

    @WNDENUMPROC
    def callback(hwnd, lparam):
        length = user32.GetWindowTextLengthW(hwnd)
        if length > 0:
            buf = ctypes.create_unicode_buffer(length + 1)
            user32.GetWindowTextW(hwnd, buf, length + 1)
            if buf.value == '原神' and user32.IsWindowVisible(hwnd):
                rect = RECT()
                user32.GetWindowRect(hwnd, ctypes.byref(rect))
                result.append((hwnd, rect.left, rect.top, rect.right, rect.bottom))
        return True

    user32.EnumWindows(callback, 0)
    return result[0] if result else None

def ensure_game_running(timeout=180):
    win = find_game_window()
    if win:
        print(f"[INFO] 原神已运行: ({win[1]},{win[2]})-({win[3]},{win[4]})")
        return win

    print("[INFO] 原神未运行, 自动启动游戏...")
    game_dir = os.path.dirname(GAME_PATH)
    subprocess.Popen([GAME_PATH], cwd=game_dir)

    print("[INFO] 等待游戏窗口出现...")
    deadline = time.time() + timeout
    while time.time() < deadline:
        time.sleep(5)
        win = find_game_window()
        if win:
            print(f"[INFO] 游戏窗口已出现, 等待加载30秒...")
            time.sleep(30)
            return win
        sys.stdout.write(f"\r[INFO] 等待中 {int(deadline - time.time())}s ")
        sys.stdout.flush()

    print("\n[ERROR] 等待游戏窗口超时!")
    return None

def focus_game():
    win = find_game_window()
    if win:
        user32.SetForegroundWindow(win[0])
        time.sleep(0.8)
    return win

def press_key(vk_code):
    """通过Windows API发送虚拟按键"""
    user32.keybd_event(vk_code, 0, 0, 0)        # key down
    user32.keybd_event(vk_code, 0, 2, 0)        # key up (KEYUP=2)

def return_game_to_main():
    """按ESC多次让游戏回到主界面 (在启动BetterGI前调用)"""
    VK_ESCAPE = 0x1B
    VK_F1 = 0x70  # F1打开派蒙菜单

    focus_game()
    time.sleep(1)

    # 按ESC 6次, 每次间隔1.5秒, 关闭所有叠加的界面
    print("  [GAME] 按ESC让游戏回主界面...")
    for i in range(6):
        press_key(VK_ESCAPE)
        time.sleep(1.5)

    # 再按F1打开派蒙菜单然后ESC关闭, 确保在主界面
    press_key(VK_F1)
    time.sleep(2)
    press_key(VK_ESCAPE)
    time.sleep(2)

    print("  [GAME] 已尝试回主界面")
    time.sleep(2)

# ===== BetterGI 管理 =====

def set_hangout_config(ending_name):
    with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
        config = json.load(f)
    config["autoSkipConfig"]["autoHangoutEndChoose"] = ending_name
    config["autoSkipConfig"]["autoHangoutEventEnabled"] = True
    config["autoSkipConfig"]["autoHangoutPressSkipEnabled"] = True
    config["autoSkipConfig"]["enabled"] = True
    with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    print(f"  [CONFIG] autoHangoutEndChoose = {ending_name}")

def write_target_file(ending):
    js_dir = os.path.join(BGI_DIR, "User", "JsScript", "AutoHangoutShinobu")
    os.makedirs(js_dir, exist_ok=True)
    target = {"endName": ending["name"], "options": ending["dialog"]}
    with open(os.path.join(js_dir, "target.json"), 'w', encoding='utf-8') as f:
        json.dump(target, f, ensure_ascii=False, indent=2)
    print(f"  [TARGET] 选项关键词: {' → '.join(ending['dialog'])}")

def read_error_log():
    """读取JS脚本记录的错误日志, 显示已知问题"""
    if not os.path.exists(ERRORS_JSON):
        return []
    try:
        with open(ERRORS_JSON, 'r', encoding='utf-8') as f:
            errors = json.load(f)
        return errors if isinstance(errors, list) else []
    except:
        return []

def show_known_errors():
    """显示已知的错误记录, 帮助避免重复犯错"""
    errors = read_error_log()
    if not errors:
        print("  [ERRORS] 无历史错误记录")
        return
    print(f"  [ERRORS] 已记录{len(errors)}条历史错误:")
    # 显示最近的5条
    for e in errors[-5:]:
        ts = e.get("time", "?")[:19]
        step = e.get("step", "?")
        msg = e.get("error", "?")
        print(f"    {ts} [{step}] {msg}")

def clear_error_log():
    """清空错误日志(每个结局开始前调用)"""
    try:
        with open(ERRORS_JSON, 'w', encoding='utf-8') as f:
            json.dump([], f)
    except:
        pass

def kill_bettergi():
    for i in range(3):
        subprocess.run(["taskkill", "/F", "/IM", "BetterGI.exe"], capture_output=True)
        time.sleep(2)
        r = subprocess.run(["tasklist", "/FI", "IMAGENAME eq BetterGI.exe"],
                           capture_output=True, text=True)
        if "BetterGI.exe" not in (r.stdout or ""):
            print("  [BGI] BetterGI stopped")
            return True
        time.sleep(1)
    print("  [BGI] [警告] BetterGI进程未能结束!")
    return False

def start_bettergi_with_script(group_name=None):
    """启动BetterGI执行指定脚本组"""
    group = group_name or SCRIPT_GROUP
    subprocess.Popen([EXE_PATH, "--startGroups", group])
    print(f"  [BGI] 启动: BetterGI.exe --startGroups {group}")
    time.sleep(5)

def get_latest_log():
    log_files = glob.glob(os.path.join(LOG_DIR, "*.log"))
    if not log_files:
        return None
    return max(log_files, key=os.path.getmtime)

# ===== 日志监控 =====

def read_new_lines(log_file, pos):
    try:
        size = os.path.getsize(log_file)
        if size < pos:
            pos = 0
        if size == pos:
            return [], pos
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            f.seek(pos)
            data = f.read()
            new_pos = f.tell()
        lines = [l.strip() for l in data.splitlines() if l.strip()]
        return lines, new_pos
    except Exception as e:
        print(f"  [LOG] 读取失败: {e}")
        return [], pos

def wait_hangout_complete(nav_timeout=600, end_timeout=1800):
    """
    监控BetterGI日志中JS脚本v10的结果
    返回: 'ended' | 'nav_failed' | 'failed' | 'timeout'
    """
    print(f"  [WAIT] 监控: 导航({nav_timeout}s) + 邀约执行({end_timeout}s)")
    log_file = get_latest_log()
    if not log_file:
        print("  [WAIT] 无日志文件!")
        return 'timeout'

    # 回退5000字节, 防止BGI启动5秒内的日志被漏读
    pos = max(0, os.path.getsize(log_file) - 5000)
    start_time = time.time()
    started_flag = [False]
    last_focus = time.time()
    error_count = 0

    while True:
        time.sleep(5)

        if time.time() - last_focus > 45:
            focus_game()
            last_focus = time.time()

        latest = get_latest_log()
        if latest != log_file:
            log_file = latest
            pos = 0
            print(f"  [WAIT] 日志轮转: {os.path.basename(log_file)}")

        lines, pos = read_new_lines(log_file, pos)
        for line in lines:
            if "NAV_RESULT: STARTED" in line:
                started_flag[0] = True
                print("\n  [WAIT] 邀约已开始, JS全程监督中...")
            elif "NAV_RESULT: ENDED" in line:
                print("\n  [WAIT] 结局达成!")
                return 'ended'
            elif "NAV_RESULT: FAILED" in line:
                print("\n  [WAIT] JS脚本报告彻底失败")
                return 'failed'
            elif "RESTART:" in line:
                print(f"\n  [BGI] {line[-90:]} (退出重做)")
            elif "ERROR_LOG:" in line:
                error_count += 1
                # 提取错误信息
                parts = line.split("ERROR_LOG:")[1].strip()
                print(f"\n  [ERROR #{error_count}] {parts[:120]}")
            elif "达成结局" in line or "选中目标选项" in line or "邀约分支" in line:
                print(f"\n  [BGI] {line[-90:]}")

        elapsed = time.time() - start_time
        if not started_flag[0] and elapsed > nav_timeout:
            print("\n  [WAIT] 导航超时, 未检测到邀约开始")
            return 'nav_failed'

        if elapsed > nav_timeout + end_timeout:
            print("\n  [WAIT] 整体超时!")
            return 'timeout'

        state = "邀约执行中" if started_flag[0] else "等待导航"
        sys.stdout.write(f"\r  [WAIT] {int(elapsed)}s [{state}] (错误{error_count})   ")
        sys.stdout.flush()

def run_one_ending(ending, ending_num, total):
    """执行单个结局, 带自动重试"""
    for attempt in range(1, MAX_RETRY_PER_ENDING + 1):
        print(f"\n  ── 结局{ending_num} 第{attempt}/{MAX_RETRY_PER_ENDING}次尝试 ──")

        # 显示已知错误(第一次尝试时)
        if attempt == 1:
            show_known_errors()

        # 1. 停止BetterGI
        print("  [1/4] 停止 BetterGI")
        kill_bettergi()

        # 2. 修改配置 + 写目标选项
        print("  [2/4] 切换结局配置")
        set_hangout_config(ending["name"])
        write_target_file(ending)

        # 3. 先ESC回主界面, 再启动BGI (防止游戏不在主界面时BGI卡住等待)
        print("  [3/4] 回主界面 + 启动 BetterGI + JS导航")
        return_game_to_main()
        start_bettergi_with_script()

        # 4. 等待完成 (导航5分钟 + 剧情15分钟, 3次尝试快速判定)
        print("  [4/4] 监控执行...")
        result = wait_hangout_complete(nav_timeout=300, end_timeout=900)

        if result == 'ended':
            print(f"  ✓ 结局{ending_num} 完成!")
            return True

        print(f"  ✗ 结局{ending_num} 未完成({result}), 准备重试...")

    print(f"  ✗✗ 结局{ending_num} 重试{MAX_RETRY_PER_ENDING}次均失败, 跳过")
    # 显示该结局的所有错误
    errors = read_error_log()
    if errors:
        print(f"  [失败原因汇总] {len(errors)}条错误记录:")
        for e in errors:
            print(f"    [{e.get('step','?')}] {e.get('error','?')}")
    return False

# ===== 邀约后任务: 采矿/钓鱼/材料 =====

def run_post_hangout_tasks():
    """邀约完成后, 依次执行采矿→钓鱼→伊安珊材料"""
    print(f"\n{'=' * 50}")
    print("  邀约任务完成, 开始执行后续任务")
    print(f"  任务组: {' → '.join(POST_HANGOUT_GROUPS)}")
    print(f"{'=' * 50}")

    # 确保BetterGI停止
    kill_bettergi()
    time.sleep(2)

    for group_name in POST_HANGOUT_GROUPS:
        print(f"\n{'─' * 40}")
        print(f"  执行: {group_name}")
        print(f"{'─' * 40}")

        # 检查脚本组配置文件是否存在
        group_json = os.path.join(BGI_DIR, "User", "ScriptGroup", f"{group_name}.json")
        if not os.path.exists(group_json):
            print(f"  [SKIP] 脚本组配置不存在: {group_name}.json")
            continue

        # 聚焦游戏
        focus_game()

        # 启动BetterGI执行该脚本组
        print(f"  [启动] BetterGI.exe --startGroups {group_name}")
        subprocess.Popen([EXE_PATH, "--startGroups", group_name])
        time.sleep(5)

        # 等待执行完成 (监控日志, 不主动判断结果, 超时后继续下一个)
        print(f"  [等待] {group_name} 执行中... (最长1800秒)")
        log_file = get_latest_log()
        pos = os.path.getsize(log_file) if log_file else 0
        start_time = time.time()
        max_wait = 1800  # 每个任务组最多等30分钟
        last_focus = time.time()
        finished = False

        while time.time() - start_time < max_wait:
            time.sleep(10)

            # 定期聚焦
            if time.time() - last_focus > 60:
                focus_game()
                last_focus = time.time()

            # 检查日志
            latest = get_latest_log()
            if latest and latest != log_file:
                log_file = latest
                pos = 0

            if log_file:
                lines, pos = read_new_lines(log_file, pos)
                for line in lines:
                    if "配置组" in line and "执行结束" in line:
                        print(f"\n  [完成] {group_name} 执行结束")
                        finished = True
                        break
                    elif "脚本" in line and "结束" in line:
                        print(f"\n  [BGI] {line[-80:]}")

                if finished:
                    break

            elapsed = int(time.time() - start_time)
            sys.stdout.write(f"\r  [{group_name}] {elapsed}s   ")
            sys.stdout.flush()

        if not finished:
            print(f"\n  [超时] {group_name} 执行超时({max_wait}s), 继续下一个")

        # 停止BetterGI
        kill_bettergi()
        time.sleep(3)

    print(f"\n{'=' * 50}")
    print("  后续任务全部完成!")
    print(f"{'=' * 50}")

# ===== 主流程 =====

def main():
    start_ending, end_ending = 1, 5
    if len(sys.argv) >= 3:
        start_ending, end_ending = int(sys.argv[1]), int(sys.argv[2])

    skip_post = "--skip-post" in sys.argv

    print("\n" + "=" * 50)
    print("  久岐忍 5结局全自动邀约 + 采矿钓鱼材料 v6")
    print("  (传送稻妻城找NPC / 3次失败放弃转一条龙 / 错误记录)")
    print("=" * 50)

    game = ensure_game_running()
    if not game:
        return

    print(f"\n将执行结局 {start_ending} 到 {end_ending}:")
    for i in range(start_ending - 1, end_ending):
        e = ENDINGS[i]
        print(f"  {i + 1}. {e['name']}")
        print(f"     选项: {' → '.join(e['dialog'])}")
    if not skip_post:
        print(f"\n邀约后任务: {' → '.join(POST_HANGOUT_GROUPS)}")
    print()

    results = {}
    give_up = False
    for i in range(start_ending - 1, end_ending):
        ending = ENDINGS[i]
        ending_num = i + 1

        print(f"\n{'─' * 50}")
        print(f"  结局 {ending_num}/{end_ending}: {ending['name']}")
        print(f"{'─' * 50}")

        # 清空错误日志(每个结局独立记录)
        clear_error_log()

        ok = run_one_ending(ending, ending_num, end_ending)
        results[ending_num] = ok

        done = sum(1 for v in results.values() if v)
        print(f"\n  进度: {done} 成功 / {len(results)} 已执行")

        # 3次尝试仍失败 → 放弃整个邀约, 记录原因, 直接跑一条龙
        if not ok:
            give_up = True
            print(f"\n  !! 结局{ending_num} 连续{MAX_RETRY_PER_ENDING}次无法推进, 按要求放弃邀约 !!")
            errors = read_error_log()
            print(f"  [放弃原因] 共记录{len(errors)}条错误:")
            for e in errors[-10:]:
                print(f"    [{e.get('step','?')}] {e.get('error','?')[:120]}")
            break

    if give_up:
        print("\n  >> 邀约自动化已放弃, 转入一条龙任务(采矿/钓鱼/材料) <<")

    # 收尾: 停BGI
    kill_bettergi()

    # 汇总
    print(f"\n{'=' * 50}")
    print("  邀约任务执行完毕!")
    print("=" * 50)
    for num, ok in sorted(results.items()):
        print(f"  结局{num}: {'✓ 完成' if ok else '✗ 失败'}")

    # 显示所有错误
    all_errors = read_error_log()
    if all_errors:
        print(f"\n  [错误记录] 共{len(all_errors)}条:")
        for e in all_errors:
            print(f"    [{e.get('step','?')}] {e.get('error','?')}")

    # 邀约后任务
    if not skip_post:
        run_post_hangout_tasks()
    else:
        print("\n  [SKIP] 跳过后续任务 (--skip-post)")

    print(f"\n日志目录: {LOG_DIR}")
    print("重跑单个结局: python auto_hangout_shinobu.py 3 3")
    print("跳过后续任务: python auto_hangout_shinobu.py 1 5 --skip-post")

if __name__ == "__main__":
    main()
