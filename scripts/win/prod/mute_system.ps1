# 系统默认音频设备静音/取消静音 (CoreAudio, 无需第三方依赖)
# 用法: mute_system.ps1            -> 静音
#       mute_system.ps1 -Unmute    -> 取消静音
#       mute_system.ps1 -Status    -> 输出当前静音状态 True/False
param(
    [switch]$Unmute,
    [switch]$Status
)

$ErrorActionPreference = 'Stop'

$code = @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
public class MMDeviceEnumeratorComObject { }

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDeviceEnumerator
{
    int NotImpl1();
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IMMDevice
{
    int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams,
                 [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IAudioEndpointVolume
{
    int NotImpl1(); int NotImpl2(); int NotImpl3(); int NotImpl4(); int NotImpl5();
    int NotImpl6(); int NotImpl7(); int NotImpl8(); int NotImpl9(); int NotImpl10(); int NotImpl11();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

public static class AudioMute
{
    private static IAudioEndpointVolume GetEndpoint()
    {
        var enumerator = (IMMDeviceEnumerator)(new MMDeviceEnumeratorComObject());
        IMMDevice device;
        enumerator.GetDefaultAudioEndpoint(0 /*eRender*/, 1 /*eMultimedia*/, out device);
        Guid iid = typeof(IAudioEndpointVolume).GUID;
        object obj;
        device.Activate(ref iid, 23 /*CLSCTX_ALL*/, IntPtr.Zero, out obj);
        return (IAudioEndpointVolume)obj;
    }

    public static void SetMute(bool mute)
    {
        GetEndpoint().SetMute(mute, Guid.Empty);
    }

    public static bool GetMute()
    {
        bool muted;
        GetEndpoint().GetMute(out muted);
        return muted;
    }
}
'@

if (-not ('AudioMute' -as [type])) {
    Add-Type -TypeDefinition $code -Language CSharp
}

if ($Status) {
    Write-Output ([AudioMute]::GetMute())
} elseif ($Unmute) {
    [AudioMute]::SetMute($false)
    Write-Output 'UNMUTED'
} else {
    [AudioMute]::SetMute($true)
    Write-Output 'MUTED'
}
