import ctypes
import ctypes.wintypes as wintypes
import time

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

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
        if user32.IsWindowVisible(hwnd):
            rect = RECT()
            user32.GetWindowRect(hwnd, ctypes.byref(rect))
            w = rect.right - rect.left
            h = rect.bottom - rect.top
            if w > 200 and h > 100:
                result.append((hwnd, buf.value, rect.left, rect.top, w, h))
    return True

user32.EnumWindows(callback, 0)

# Find exact match for '原神'
game_hwnd = None
for hwnd, title, x, y, w, h in result:
    print(f'Window: hwnd={hwnd}, title="{title}", pos=({x},{y}), size={w}x{h}')
    if title == '原神':
        game_hwnd = hwnd
        game_rect = (x, y, w, h)

if game_hwnd:
    print(f'\nGame window: hwnd={game_hwnd}, pos=({game_rect[0]},{game_rect[1]}), size={game_rect[2]}x{game_rect[3]}')
    user32.SetForegroundWindow(game_hwnd)
    time.sleep(3)

    fg = user32.GetForegroundWindow()
    buf = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(fg, buf, 256)
    print(f'Foreground: {buf.value}')

    hdc = user32.GetDC(None)
    for name, x, y in [('center', 853, 533), ('top', 853, 200), ('left', 300, 500), ('bottom', 853, 850)]:
        pixel = gdi32.GetPixel(hdc, x, y)
        r, g, b = pixel & 0xFF, (pixel >> 8) & 0xFF, (pixel >> 16) & 0xFF
        print(f'  {name} ({x},{y}): RGB({r},{g},{b})')
    user32.ReleaseDC(None, hdc)
else:
    print('Game window not found with exact title!')
