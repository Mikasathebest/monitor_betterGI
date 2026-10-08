#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Windows 脚本转换器: UTF-8(单 BOM) + CRLF
# PS 5.1 把无 BOM 的 UTF-8 当 GBK 读 → CJK 断引号; 双 BOM → "不是有效脚本文件"
# 用法: python3 to_win.py src.ps1 dst.ps1
import sys
import pathlib

src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
text = src.read_text(encoding="utf-8-sig")  # utf-8-sig 自动剥掉已有 BOM, 防双 BOM
text = text.replace("\r\n", "\n").replace("\n", "\r\n")  # 统一 CRLF
dst.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
print(f"{src.name} -> {dst} ({dst.stat().st_size} bytes, BOM+CRLF)")
