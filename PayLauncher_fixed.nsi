;======================================================
; 付费启动器 — v7.3 自动轮询支付 (放大窗口 + TEMP 路径统一)
; 修复：SetTimer 回调、curl.exe 释放时机、GDI 清理、路径统一
; 改动：窗口放大至 750x620；所有文件统一释放到 $TEMP\PayLauncher
;======================================================

!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "WinMessages.nsh"
!include "FileFunc.nsh"

!pragma warning disable 6001

Name "软件激活"
OutFile "PayLauncher.exe"
InstallDir "$TEMP\PayLauncher"
RequestExecutionLevel user
ShowInstDetails nevershow

; 定时器 ID
!define TIMER_ID 1234
; 轮询间隔（毫秒）
!define POLL_INTERVAL 3000

;------------------------------------------------------
; 窗口放大配置（750x620 点）
;------------------------------------------------------
!define WINDOW_W 750
!define WINDOW_H 620

;------------------------------------------------------
; 变量
;------------------------------------------------------
Var Dialog
Var Label_Info
Var Label_Status
Var Btn_Exit
Var OrderId
Var PayApiUrl
Var PayPageUrl
Var ProductAmount
Var ProductName
Var hFont1
Var hFont2
Var PollingActive        ; 1=正在轮询, 0=已停止
Var CurlPath              ; curl.exe 实际路径

Page custom PayPage PayPageLeave

;------------------------------------------------------
; [关键] 预释放区段 - 在页面显示之前释放所有资源
; 所有文件统一释放到 $TEMP\PayLauncher（用户缓存临时目录）
;------------------------------------------------------
Section "-PreExtract"
  ; 统一使用用户临时目录 $TEMP\PayLauncher
  CreateDirectory "$TEMP\PayLauncher"

  ; 释放 curl.exe 到 $TEMP\PayLauncher
  SetOutPath "$TEMP\PayLauncher"
  File "assets\curl.exe"

  ; 释放运行程序
  File "run.exe"

  ; 初始化变量
  StrCpy $PayApiUrl "http://localhost:3000/api/payment"
  StrCpy $ProductAmount "9.90"
  StrCpy $ProductName "专业版激活码"
  StrCpy $OrderId ""
  StrCpy $PayPageUrl ""
  StrCpy $PollingActive "0"
  StrCpy $CurlPath "$TEMP\PayLauncher\curl.exe"
SectionEnd

;------------------------------------------------------
; 主区段 - Section Main 在页面之后执行，只做最终处理
;------------------------------------------------------
Section "Main"
  ; 文件已在 "-PreExtract" 中释放，这里无需重复
SectionEnd

;------------------------------------------------------
; GUI 初始化 — 放大安装器窗口
;------------------------------------------------------
Function .onGUIInit
  ; 获取屏幕尺寸
  System::Call "user32::GetSystemMetrics(i 0)i.r0"  ; SM_CXSCREEN
  System::Call "user32::GetSystemMetrics(i 1)i.r1"  ; SM_CYSCREEN

  ; 计算窗口居中位置
  IntOp $2 ${WINDOW_W}
  IntOp $3 ${WINDOW_H}
  IntOp $4 $0 - $2
  IntOp $4 $4 / 2
  IntOp $5 $1 - $3
  IntOp $5 $5 / 2

  ; 查找 NSIS 安装器窗口并放大居中
  System::Call "user32::FindWindow(t 'NSIS_Window_Class',t '')i.r6"
  ${If} $6 != 0
    System::Call "user32::SetWindowPos(i $6, i 0, i $4, i $5, i ${WINDOW_W}, i ${WINDOW_H}, i 0x0004)"
  ${EndIf}
FunctionEnd

;======================================================
; 支付页面
;======================================================
Function PayPage
  !insertmacro MUI_HEADER_TEXT "" ""

  ; curl.exe 路径（统一从 $TEMP\PayLauncher 加载）
  StrCpy $CurlPath "$TEMP\PayLauncher\curl.exe"

  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  CreateFont $hFont1 "微软雅黑" 11 700
  CreateFont $hFont2 "微软雅黑" 10 400

  ${NSD_CreateLabel} 0 20u 100% 40u "正在打开支付页面...$\r$\n$\r$\n请在浏览器中完成支付，支付成功后将自动继续。"
  Pop $Label_Info
  SetCtlColors $Label_Info "333333" transparent
  SendMessage $Label_Info ${WM_SETFONT} $hFont2 1

  ${NSD_CreateLabel} 0 70u 100% 14u "正在创建订单..."
  Pop $Label_Status
  SetCtlColors $Label_Status "4361EE" transparent
  SendMessage $Label_Status ${WM_SETFONT} $hFont1 1

  ${NSD_CreateLabel} 110u 110u 90u 22u "退出"
  Pop $Btn_Exit
  SetCtlColors $Btn_Exit "999999" "F0F0F0"
  SendMessage $Btn_Exit ${WM_SETFONT} $hFont2 1
  ${NSD_OnClick} $Btn_Exit OnExit

  ; 自动创建订单 + 打开浏览器
  Call AutoCreateOrder

  ; ===== 手动消息循环 + SetTimer 轮询 =====
  ${If} $OrderId != ""
    StrCpy $PollingActive "1"

    System::Call "user32::SetTimer(i $Dialog, i ${TIMER_ID}, i ${POLL_INTERVAL}, i 0)"

    loop_msg:
      ${If} $PollingActive != "1"
        Goto end_msg
      ${EndIf}

      System::Alloc 28
      Pop $9
      System::Call "user32::PeekMessage(i r9, i $Dialog, i 0, i 0, i 1)i.r1"
      ${If} $1 != 0
        System::Call "*$9(i .r2)"
        ${If} $2 == ${WM_QUIT}
          System::Free $9
          Goto end_msg
        ${EndIf}
        System::Call "user32::TranslateMessage(i r9)"
        System::Call "user32::DispatchMessageA(i r9)"
        ${If} $2 == ${WM_TIMER}
          System::Call "*$9(i .r2, i .r3, i .r4, i .r5)"
          ${If} $4 == ${TIMER_ID}
            Call PollPaymentStatus
          ${EndIf}
        ${EndIf}
      ${EndIf}
      System::Free $9

      Sleep 50
      Goto loop_msg

    end_msg:
    System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"
  ${Else}
    ; 没成功创建订单，标准模态显示让用户点退出
    nsDialogs::Show
  ${EndIf}

  ; 清理 GDI 对象
  System::Call "gdi32::DeleteObject(i $hFont1)"
  System::Call "gdi32::DeleteObject(i $hFont2)"
FunctionEnd

;======================================================
; 轮询支付状态
;======================================================
Function PollPaymentStatus
  ${If} $OrderId == ""
    Return
  ${EndIf}

  IfFileExists "$CurlPath" 0 poll_fail

  nsExec::ExecToStack '"$CurlPath" -s --connect-timeout 5 --max-time 8 "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2

    ${If} $2 == "paid"
      StrCpy $PollingActive "0"
      System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"

      SetCtlColors $Label_Status "00A854" transparent
      ${NSD_SetText} $Label_Status "支付成功！正在启动程序..."
      ${NSD_SetText} $Label_Info "支付已完成，感谢购买！"
      Sleep 1500

      SendMessage $Dialog ${WM_CLOSE} 0 0
    ${EndIf}
  ${EndIf}

  Return

  poll_fail:
    StrCpy $PollingActive "0"
    System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "错误：找不到 curl.exe$\r$\n检查路径：$CurlPath"
FunctionEnd

;======================================================
; 自动创建订单 + 打开浏览器（所有文件操作统一使用 $TEMP\PayLauncher）
;======================================================
Function AutoCreateOrder

  ; 检查 curl.exe
  IfFileExists "$CurlPath" curl_ok
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "错误：找不到 curl.exe$\r$\n检查路径：$CurlPath"
    Return
  curl_ok:

  ; 生成订单号
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
  System::Call 'kernel32::GetTickCount()i.r0'
  StrCpy $OrderId "$2$4$5$6$0"

  ; 写请求体（统一到 $TEMP\PayLauncher）
  StrCpy $0 '{"order_id":"$OrderId","amount":$ProductAmount,"payment_type":"link","product":"$ProductName"}'
  FileOpen $1 "$TEMP\PayLauncher\req_body.json" w
  FileWrite $1 $0
  FileClose $1

  ; POST 创建订单
  nsExec::ExecToStack '"$CurlPath" -v --connect-timeout 10 --max-time 15 -X POST "$PayApiUrl/create_order" -H "Content-Type: application/json" -d @"$TEMP\PayLauncher\req_body.json" 2>&1'
  Pop $0
  Pop $1

  ; 保存响应用于诊断（统一到 $TEMP\PayLauncher）
  FileOpen $2 "$TEMP\PayLauncher\last_response.txt" w
  FileWrite $2 "RC=$0$\r$\n$1"
  FileClose $2

  ${If} $1 == ""
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "连接失败：服务器无响应$\r$\n请确认后端已启动（cd backend && npm start）"
    Return
  ${EndIf}

  ${If} $0 != "0"
    StrCpy $3 $1 80
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "curl 错误($0)：$3..."
    Return
  ${EndIf}

  ; 提取 pay_url 或 qr_url
  Push "pay_url"
  Push $1
  Call SimpleJsonExtract
  Pop $2
  ${If} $2 == ""
    Push "qr_url"
    Push $1
    Call SimpleJsonExtract
    Pop $2
  ${EndIf}

  ${If} $2 != ""
    StrCpy $PayPageUrl "$2"
    ExecShell "open" "$PayPageUrl"
    SetCtlColors $Label_Status "00A854" transparent
    ${NSD_SetText} $Label_Status "已打开支付页面，支付后自动继续"
  ${Else}
    StrCpy $3 $1 60
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "未获取到支付链接：$3..."
  ${EndIf}
FunctionEnd

;======================================================
; 退出
;======================================================
Function OnExit
  StrCpy $PollingActive "0"
  System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"
  MessageBox MB_YESNO "确定退出？" IDYES +2
  Return
  Quit
FunctionEnd

;======================================================
; 页面离开 - 最终验证
;======================================================
Function PayPageLeave
  ${If} $OrderId == ""
    Return
  ${EndIf}

  IfFileExists "$CurlPath" 0 leave_fail

  nsExec::ExecToStack '"$CurlPath" -s --connect-timeout 5 --max-time 10 "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1
  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2
    ${If} $2 != "paid"
      MessageBox MB_OK "支付未完成。"
      Abort
    ${EndIf}
  ${Else}
    leave_fail:
    MessageBox MB_OK "无法连接服务器验证支付状态。"
    Abort
  ${EndIf}
FunctionEnd

;======================================================
; 后置区段 - 启动目标程序
;======================================================
Section "-Post"
  ${If} ${FileExists} "$TEMP\PayLauncher\run.exe"
    ExecWait '"$TEMP\PayLauncher\run.exe"'
  ${EndIf}
  RMDir /r "$TEMP\PayLauncher"
SectionEnd

;======================================================
; 辅助函数
;======================================================

Function SimpleJsonExtract
  Exch $0
  Exch 1
  Exch $1
  StrCpy $2 '"$0":"'
  Push $2
  Push $1
  Call StrStr
  Pop $3
  ${If} $3 == ""
    StrCpy $2 '"$0":'
    Push $2
    Push $1
    Call StrStr
    Pop $3
    ${If} $3 == ""
      Push ""
      Goto done
    ${EndIf}
    StrLen $4 $2
    StrCpy $3 $3 "" $4
    StrCpy $5 ""
    loop_num:
      StrCpy $6 $3 1
      ${If} $6 == ","
      ${OrIf} $6 == "}"
        Goto done_num
      ${EndIf}
      StrCpy $5 "$5$6"
      StrCpy $3 $3 "" 1
      StrCmp $3 "" done_num loop_num
    done_num:
    Push $5
    Goto done
  ${EndIf}
  StrLen $4 $2
  StrCpy $3 $3 "" $4
  StrCpy $5 ""
  loop:
    StrCpy $6 $3 1
    ${If} $6 == '"'
      Goto done
    ${EndIf}
    StrCpy $5 "$5$6"
    StrCpy $3 $3 "" 1
    StrCmp $3 "" done loop
  done:
    Pop $1
    Pop $0
    Exch $5
FunctionEnd

Function StrStr
  Exch $0
  Exch
  Exch $1
  Push $2
  Push $3
  StrLen $2 $0
  StrCpy $3 0
  loop_strstr:
    StrCpy $4 $1 $2 $3
    StrCmp $4 $0 found
    StrCmp $1 "" notfound
    IntOp $3 $3 + 1
    Goto loop_strstr
  found:
    StrCpy $0 $1 "" $3
    Goto end_strstr
  notfound:
    StrCpy $0 ""
  end_strstr:
    Pop $3
    Pop $2
    Pop $1
    Exch $0
FunctionEnd
