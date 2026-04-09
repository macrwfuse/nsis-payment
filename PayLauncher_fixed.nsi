;======================================================
; 付费启动器 — v7 自动轮询支付 + 详细错误诊断
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

!define TIMER_ID 1234

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

Page custom PayPage PayPageLeave

Section "Main"
  SetOutPath "$TEMP\PayLauncher"
  File "assets\curl.exe"
  File "run.exe"
  StrCpy $PayApiUrl "https://your-server.com/api/payment"
  StrCpy $ProductAmount "9.90"
  StrCpy $ProductName "专业版激活码"
  StrCpy $OrderId ""
  StrCpy $PayPageUrl ""
SectionEnd

;======================================================
; 页面
;======================================================
Function PayPage
  !insertmacro MUI_HEADER_TEXT "" ""

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

  ; ===== 启动自动轮询定时器（3秒一次）=====
  ${If} $OrderId != ""
    System::Call "user32::SetTimer(i $Dialog, i ${TIMER_ID}, i 3000, k OnTimerCallback)"
  ${EndIf}

  nsDialogs::Show

  ; 清理
  System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"
  System::Call 'gdi32::DeleteObject(i $hFont1)'
  System::Call 'gdi32::DeleteObject(i $hFont2)'
FunctionEnd

;======================================================
; 定时器回调 — 每 3 秒自动检查支付状态
; SetTimer callback 签名: TimerProc(hwnd, uMsg, idEvent, dwTime)
; NSIS 中参数从栈上 Pop 取出（从右到左）
;======================================================
Function OnTimerCallback
  ; 清除回调参数（dwTime, idEvent, uMsg, hwnd）
  Pop $R0  ; dwTime
  Pop $R1  ; idEvent (timer id)
  Pop $R2  ; uMsg
  Pop $R3  ; hwnd

  ${If} $OrderId == ""
    Return
  ${EndIf}

  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s --connect-timeout 5 --max-time 8 "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2

    ${If} $2 == "paid"
      ; 停止定时器
      System::Call "user32::KillTimer(i $R3, i ${TIMER_ID})"
      ; 更新界面
      SetCtlColors $Label_Status "00A854" transparent
      ${NSD_SetText} $Label_Status "支付成功！正在启动程序..."
      ${NSD_SetText} $Label_Info "支付已完成，感谢购买！"
      Sleep 1500
      SendMessage $Dialog ${WM_CLOSE} 0 0
    ${EndIf}
  ${EndIf}
FunctionEnd

;======================================================
; 自动创建订单 + 打开浏览器
;======================================================
Function AutoCreateOrder

  ; 检查 curl.exe
  IfFileExists "$TEMP\PayLauncher\curl.exe" curl_ok
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "错误：找不到 curl.exe"
    Return
  curl_ok:

  ; 生成订单号
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
  System::Call 'kernel32::GetTickCount()i.r0'
  StrCpy $OrderId "$2$4$5$6$0"

  ; 写请求体
  StrCpy $0 '{"order_id":"$OrderId","amount":$ProductAmount,"payment_type":"link","product":"$ProductName"}'
  FileOpen $1 "$TEMP\PayLauncher\req_body.json" w
  FileWrite $1 $0
  FileClose $1

  ; POST 创建订单（捕获 stderr）
  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -v --connect-timeout 10 --max-time 15 -X POST "$PayApiUrl/create_order" -H "Content-Type: application/json" -d @"$TEMP\PayLauncher\req_body.json" 2>&1'
  Pop $0   ; return code
  Pop $1   ; output (stdout + stderr)

  ; 保存完整响应用于诊断
  FileOpen $2 "$TEMP\PayLauncher\last_response.txt" w
  FileWrite $2 "RC=$0$\r$\n$1"
  FileClose $2

  ${If} $1 == ""
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "连接失败：服务器无响应$\r$\n请确认后端已启动（cd backend && npm start）"
    Return
  ${EndIf}

  ${If} $0 != "0"
    ; curl 返回非 0，显示错误
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
    ; 显示服务器返回的内容帮助诊断
    StrCpy $3 $1 60
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "未获取到支付链接：$3..."
  ${EndIf}
FunctionEnd

;======================================================
; 退出
;======================================================
Function OnExit
  MessageBox MB_YESNO "确定退出？" IDYES +2
  Return
  Quit
FunctionEnd

;======================================================
; 页面离开
;======================================================
Function PayPageLeave
  ${If} $OrderId == ""
    Return
  ${EndIf}
  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s --connect-timeout 5 --max-time 10 "$PayApiUrl/check_status?order_id=$OrderId"'
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
  ${EndIf}
FunctionEnd

Section "-Post"
  ExecWait '"$TEMP\PayLauncher\run.exe"'
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
