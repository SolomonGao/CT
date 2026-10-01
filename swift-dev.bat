@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" -arch=x64 >nul
set "PATH=C:\Users\73823\AppData\Local\Programs\Swift\Toolchains\6.4.0+Asserts\usr\bin;%PATH%"
set "SDKROOT=C:\Users\73823\AppData\Local\Programs\Swift\Platforms\6.4.0\Windows.platform\Developer\SDKs\Windows.sdk"
set "PATH=C:\Users\73823\AppData\Local\Programs\Swift\Runtimes\6.4.0\usr\bin;%PATH%"
cd /d "C:\Users\73823\Desktop\projects\CT"
swift %*
