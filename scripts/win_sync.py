#!/usr/bin/env python3
"""Windows 脚本部署/漂移检查。Windows 端脚本平铺在 BGI_WIN_HOME (C:/Users/djf20), 仓库按 prod/setup/tools/archive 分目录

用法:
  python3 scripts/win_sync.py push <文件名>...   转 BOM+CRLF 后 scp 到 Windows (文件名在 scripts/win/*/ 下查找)
  python3 scripts/win_sync.py diff [文件名...]    拉回 Windows 上的同名文件与仓库对比 (默认对比全部 prod/)

diff 发现不一致时: 先确认哪边是对的 —— Windows 上被现场改过就拉回来提交, 仓库更新了就 push。
"""
import difflib
import os
import subprocess
import sys
import tempfile
from pathlib import Path

from to_win import to_win_bytes

ROOT = Path(__file__).resolve().parent.parent
WIN_DIR = ROOT / "scripts" / "win"


def load_env():
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            k, sep, v = line.partition("=")
            if sep and not k.lstrip().startswith("#"):
                os.environ.setdefault(k.strip(), v.split("#")[0].strip())


def find(name: str) -> Path:
    hits = list(WIN_DIR.glob(f"*/{name}"))
    if len(hits) != 1:
        sys.exit(f"{name}: 在 scripts/win/*/ 下找到 {len(hits)} 个")
    return hits[0]


def normalize(data: bytes) -> str:
    return data.decode("utf-8-sig", errors="replace").replace("\r\n", "\n").rstrip() + "\n"


def push(host: str, home: str, names: list[str]):
    with tempfile.TemporaryDirectory() as tmp:
        for name in names:
            src = find(name)
            dst = Path(tmp) / name
            # ps1/vbs 需要 BOM+CRLF; py/js/txt 原样传
            dst.write_bytes(to_win_bytes(src.read_text(encoding="utf-8-sig")) if src.suffix in (".ps1", ".vbs")
                            else src.read_bytes())
            r = subprocess.run(["scp", "-q", str(dst), f"{host}:{home}/{name}"], capture_output=True, text=True)
            print(f"{'✓' if r.returncode == 0 else '✗'} {src.relative_to(ROOT)} → {home}/{name} {r.stderr.strip()}")


def diff(host: str, home: str, names: list[str]):
    names = names or sorted(p.name for p in (WIN_DIR / "prod").iterdir() if p.is_file())
    same = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name in names:
            local = find(name)
            remote = Path(tmp) / name
            r = subprocess.run(["scp", "-q", f"{host}:{home}/{name}", str(remote)], capture_output=True, text=True)
            if r.returncode != 0:
                print(f"? {name}: Windows 上没有 ({r.stderr.strip()[:80]})")
                continue
            a, b = normalize(local.read_bytes()), normalize(remote.read_bytes())
            if a == b:
                same += 1
                continue
            print(f"≠ {name}")
            sys.stdout.writelines(difflib.unified_diff(
                a.splitlines(True), b.splitlines(True), f"repo/{local.relative_to(WIN_DIR)}", f"win/{name}", n=1))
    print(f"\n一致 {same}/{len(names)}")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("push", "diff"):
        sys.exit(__doc__)
    load_env()
    host = os.environ.get("BGI_SSH_HOST") or sys.exit("缺少 BGI_SSH_HOST (见 .env.example)")
    home = os.environ.get("BGI_WIN_HOME", "C:/Users/djf20")
    cmd, names = sys.argv[1], sys.argv[2:]
    if cmd == "push":
        if not names:
            sys.exit("push 需要文件名")
        push(host, home, names)
    else:
        diff(host, home, names)


if __name__ == "__main__":
    main()
