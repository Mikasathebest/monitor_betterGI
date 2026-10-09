# fix_protocol.ps1 - mark privacy protocol v62 as agreed locally
# game must be closed before running
$regPath = "HKCU:\Software\miHoYo\" + [char]0x539F + [char]0x795E
Write-Output "reg path: $regPath"

function Set-RegJson($name, $json) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($json + "`0")
  Set-ItemProperty -Path $regPath -Name $name -Value $bytes -Type Binary
  Write-Output "set $name"
}

# agreed protocol version 61 -> 62 (match launch version)
Set-RegJson 'MIHOYOSDK_PROTOCOL_1_280789792_zh-cn_h2661690921' '{"id":0,"app_id":4,"language":"zh-cn","user_proto":"","priv_proto":"","major":62,"minimum":0,"create_time":"0","teenager_proto":"","third_proto":"","full_priv_proto":""}'
Set-RegJson 'MIHOYOSDK_PROTOCOL__zh-cn_h1189219383' '{"id":0,"app_id":4,"language":"zh-cn","user_proto":"","priv_proto":"","major":62,"minimum":0,"create_time":"0","teenager_proto":"","third_proto":"","full_priv_proto":""}'

# disable show flags
Set-RegJson 'MIHOYOSDK_PROTOCOL_LAUNCH_SHOW_FLAG_0_zh-cn_h887883978' '{"isShow":false,"isUpdate":false}'
Set-RegJson 'MIHOYOSDK_USER_AGREEMENT_SHOW_FLAG_zh-cn_h466595801' '{"isShow":false,"isUpdate":false}'

Write-Output "done"
