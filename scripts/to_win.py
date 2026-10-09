#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Windows 脚本转换器: UTF-8(单 BOM) + CRLF
# PS 5.1 把无 BOM 的 UTF-8 当 GBK 读 → CJK 断引号; 双 BOM → "不是有效脚本文件"
# 用法: python3 to_win.py src.ps1 dst.ps1   (也可 import 后调 convert)
import sys
import pathlib


def to_win_bytes(text: str) -> bytes:
    """文本 → 单 BOM + CRLF 字节。先剥已有 BOM 防双 BOM"""
    text = text.lstrip("﻿")
    text = text.replace("\r\n", "\n").replace("\n", "\r\n")  # 统一 CRLF
    return b"\xef\xbb\xbf" + text.encode("utf-8")


def convert(src: pathlib.Path, dst: pathlib.Path) -> int:
    """src 文件 → dst (BOM+CRLF), 返回写入字节数"""
    data = to_win_bytes(src.read_text(encoding="utf-8-sig"))
    dst.write_bytes(data)
    return len(data)


if __name__ == "__main__":
    src, dst = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    size = convert(src, dst)
    print(f"{src.name} -> {dst} ({size} bytes, BOM+CRLF)")
