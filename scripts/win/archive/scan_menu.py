import ctypes
import ctypes.wintypes as wintypes
import time

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

class RECT(ctypes.Structure):
    _fields_ = [('left', wintypes.LONG), ('top', wintypes.LONG),
                ('right', wintypes.LONG), ('bottom', wintypes.LONG)]

result = []

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

if result:
    hwnd, l, t, r, b = result[0]
    print(f'Game window: ({l},{t})-({r},{b}), size={r-l}x{b-t}')
    user32.SetForegroundWindow(hwnd)
    time.sleep(1)

    # Press ESC to open Paimon menu
    user32.keybd_event(0x1B, 0, 0, None)
    time.sleep(0.05)
    user32.keybd_event(0x1B, 0, 2, None)
    time.sleep(2)

    # Scan the left side of game window for icons
    hdc = user32.GetDC(None)

    # Scan vertical line at different x positions
    for x_off in [50, 80, 100, 120, 150]:
        scan_x = l + x_off
        print(f'\n--- Scanning x={scan_x} (offset {x_off}) ---')
        prev_color = None
        edge_count = 0
        for y in range(t + 50, b - 50, 3):
            pixel = gdi32.GetPixel(hdc, scan_x, y)
            rv = pixel & 0xFF
            gv = (pixel >> 8) & 0xFF
            bv = (pixel >> 16) & 0xFF
            if prev_color and (abs(rv - prev_color[0]) > 40 or abs(gv - prev_color[1]) > 40 or abs(bv - prev_color[2]) > 40):
                if edge_count < 30:
                    print(f'  EDGE y={y-t} (abs={y}): RGB({rv},{gv},{bv})')
                edge_count += 1
            prev_color = (rv, gv, bv)
        print(f'  Total edges: {edge_count}')

    # Also scan a wider area - check for the hangout icon
    # In Genshin Impact, the Paimon menu has icons on the left in a column
    # Let's scan a grid to find icon-like regions
    print('\n--- Grid scan (looking for icons) ---')
    for y_off in range(100, 700, 50):
        row = []
        for x_off in range(30, 300, 30):
            pixel = gdi32.GetPixel(hdc, l + x_off, t + y_off)
            rv = pixel & 0xFF
            gv = (pixel >> 8) & 0xFF
            bv = (pixel >> 16) & 0xFF
            # Mark bright pixels (icons are usually brighter than background)
            if rv > 100 or gv > 100 or bv > 100:
                row.append(f'{x_off}:{rv},{gv},{bv}')
        if row:
            print(f'  y={y_off}: {row[:5]}')

    user32.ReleaseDC(None, hdc)
else:
    print('Game not found!')
