import ctypes
import ctypes.wintypes as wintypes
import time
import os

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32

WNDENUMPROC = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)

class RECT(ctypes.Structure):
    _fields_ = [('left', wintypes.LONG), ('top', wintypes.LONG),
                ('right', wintypes.LONG), ('bottom', wintypes.LONG)]

# Find game window
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

if not result:
    print('Game not found!')
    exit(1)

hwnd, l, t, r, b = result[0]
print(f'Game window: ({l},{t})-({r},{b}), size={r-l}x{b-t}')

# Bring to foreground
user32.SetForegroundWindow(hwnd)
time.sleep(2)

# Press ESC to open Paimon menu (or close it if already open, then open again)
user32.keybd_event(0x1B, 0, 0, None)  # ESC down
time.sleep(0.05)
user32.keybd_event(0x1B, 0, 2, None)  # ESC up
time.sleep(2)

# Take screenshot of entire screen
SRCCOPY = 0x00CC0020
width = user32.GetSystemMetrics(0)
height = user32.GetSystemMetrics(1)
print(f'Screen: {width}x{height}')

hdc = user32.GetDC(None)
mdc = gdi32.CreateCompatibleDC(hdc)
bmp = gdi32.CreateCompatibleBitmap(hdc, width, height)
gdi32.SelectObject(mdc, bmp)
gdi32.BitBlt(mdc, 0, 0, width, height, hdc, 0, 0, SRCCOPY)

# Save as BMP
save_path = r'd:\Projects\genshin_detect\captures\paimon_menu.bmp'

class BMPINFOHEADER(ctypes.Structure):
    _fields_ = [
        ('biSize', ctypes.c_uint32), ('biWidth', ctypes.c_int32),
        ('biHeight', ctypes.c_int32), ('biPlanes', ctypes.c_uint16),
        ('biBitCount', ctypes.c_uint16), ('biCompression', ctypes.c_uint32),
        ('biSizeImage', ctypes.c_uint32), ('biXPelsPerMeter', ctypes.c_int32),
        ('biYPelsPerMeter', ctypes.c_int32), ('biClrUsed', ctypes.c_uint32),
        ('biClrImportant', ctypes.c_uint32),
    ]

buffer_size = width * height * 4
pixel_data = (ctypes.c_ubyte * buffer_size)()

bmi = BMPINFOHEADER()
bmi.biSize = ctypes.sizeof(BMPINFOHEADER)
bmi.biWidth = width
bmi.biHeight = -height
bmi.biPlanes = 1
bmi.biBitCount = 32
bmi.biCompression = 0

ret = gdi32.GetDIBits(mdc, bmp, 0, height, pixel_data, ctypes.byref(bmi), 0)
print(f'GetDIBits returned: {ret}')

if ret:
    with open(save_path, 'wb') as f:
        file_header_size = 14
        info_header_size = 40
        pixel_array_offset = file_header_size + info_header_size
        file_size = pixel_array_offset + buffer_size
        f.write(b'BM')
        f.write(file_size.to_bytes(4, 'little'))
        f.write((0).to_bytes(4, 'little'))
        f.write(pixel_array_offset.to_bytes(4, 'little'))
        f.write(info_header_size.to_bytes(4, 'little'))
        f.write(width.to_bytes(4, 'little', signed=True))
        f.write(height.to_bytes(4, 'little', signed=True))
        f.write((1).to_bytes(2, 'little'))
        f.write((32).to_bytes(2, 'little'))
        f.write((0).to_bytes(4, 'little'))
        f.write(buffer_size.to_bytes(4, 'little'))
        f.write((0).to_bytes(4, 'little', signed=True))
        f.write((0).to_bytes(4, 'little', signed=True))
        f.write((0).to_bytes(4, 'little'))
        f.write((0).to_bytes(4, 'little'))
        f.write(bytes(pixel_data))
    print(f'Screenshot saved: {save_path} ({os.path.getsize(save_path)} bytes)')

    # Check some pixels to verify it's the game
    for name, x, y in [('game_center', l + 647, t + 378),
                       ('game_topleft', l + 10, t + 10),
                       ('left_icons', l + 80, t + 200),
                       ('left_icons2', l + 80, t + 400)]:
        pixel = gdi32.GetPixel(hdc, x, y)
        rv = pixel & 0xFF
        gv = (pixel >> 8) & 0xFF
        bv = (pixel >> 16) & 0xFF
        print(f'  {name} ({x},{y}): RGB({rv},{gv},{bv})')
else:
    print('GetDIBits failed!')

gdi32.DeleteDC(mdc)
gdi32.DeleteObject(bmp)
user32.ReleaseDC(None, hdc)
