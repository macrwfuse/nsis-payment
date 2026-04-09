;======================================================
; 付费启动器 — v7.1 自动轮询支付 (修复版)
; 修复：SetTimer 回调机制、GDI 句柄清理、路径健壮性
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

Page custom PayPage PayPageLeave

;------------------------------------------------------
; 主区段 - 释放资源
;------------------------------------------------------
Section "Main"
  ; 先创建目录
  CreateDirectory "$INSTDIR"

  SetOutPath "$INSTDIR"
  File "assets\curl.exe"
  File "run.exe"

  ; 初始化
  StrCpy $PayApiUrl "http://localhost:3000/api/payment"
  StrCpy $ProductAmount "9.90"
  StrCpy $ProductName "专业版激活码"
  StrCpy $OrderId ""
  StrCpy $PayPageUrl ""
  StrCpy $PollingActive "0"
SectionEnd

;======================================================
; 支付页面
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

  ; ===== [修复1] 使用手动消息循环 + SetTimer 替代不可靠的回调 =====
  ${If} $OrderId != ""
    StrCpy $PollingActive "1"

    ; 设置 Windows 定时器（向对话框窗口发 WM_TIMER 消息）
    System::Call "user32::SetTimer(i $Dialog, i ${TIMER_ID}, i ${POLL_INTERVAL}, i 0)"

    ; 手动消息循环：PeekMessage 非阻塞，每轮检查定时器
    loop_msg:
      ${If} $PollingActive != "1"
        Goto end_msg
      ${EndIf}

      ; 非阻塞获取消息（PM_REMOVE = 取出并分发）
      System::Call "user32::PeekMessage(*i0r0, i $Dialog, i 0, i 0, i 1)i.r1"
      ${If} $1 != 0
        ; 检查是否是退出消息
        System::Call "*$0(i .r2)"
        ${If} $2 == ${WM_QUIT}
          Goto end_msg
        ${EndIf}
        ; 分发消息（TranslateMessage + DispatchMessage）
        System::Call "user32::TranslateMessage(i r0)"
        System::Call "user32::DispatchMessageA(i r0)"

        ; 检查是否收到 WM_TIMER（定时器触发轮询）
        ${If} $2 == ${WM_TIMER}
          System::Call "*$0(i .r2, i .r3, i .r4, i .r5)"
          ${If} $4 == ${TIMER_ID}
            Call PollPaymentStatus
          ${EndIf}
        ${EndIf}
      ${EndIf}

      ; 短暂休眠，降低 CPU 占用
      Sleep 50
      Goto loop_msg

    end_msg:
    ; 清理定时器
    System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"
  ${Else}
    ; 没有成功创建订单，用标准模态显示（让用户点退出）
    nsDialogs::Show
  ${EndIf}

  ; 清理 GDI 对象
  System::Call "gdi32::DeleteObject(i $hFont1)"
  System::Call "gdi32::DeleteObject(i $hFont2)"
FunctionEnd

;======================================================
; [修复2] 轮询支付状态（独立函数，从消息循环调用）
;======================================================
Function PollPaymentStatus
  ${If} $OrderId == ""
    Return
  ${EndIf}

  ; ====== [修复3] 路径检查 + 使用 $INSTDIR ======
  IfFileExists "$INSTDIR\curl.exe" 0 poll_fail

  nsExec::ExecToStack '"$INSTDIR\curl.exe" -s --connect-timeout 5 --max-time 8 "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2

    ${If} $2 == "paid"
      ; 停止轮询
      StrCpy $PollingActive "0"
      System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"

      ; 更新界面
      SetCtlColors $Label_Status "00A854" transparent
      ${NSD_SetText} $Label_Status "支付成功！正在启动程序..."
      ${NSD_SetText} $Label_Info "支付已完成，感谢购买！"
      Sleep 1500

      ; 发送 WM_CLOSE 关闭对话框（退出消息循环）
      SendMessage $Dialog ${WM_CLOSE} 0 0
    ${EndIf}
  ${EndIf}

  Return

  poll_fail:
    ; curl.exe 不存在，停止轮询并报错
    StrCpy $PollingActive "0"
    System::Call "user32::KillTimer(i $Dialog, i ${TIMER_ID})"
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "错误：找不到 curl.exe（$INSTDIR\curl.exe）"
FunctionEnd

;======================================================
; 自动创建订单 + 打开浏览器
;======================================================
Function AutoCreateOrder

  ; ====== [修复4] 检查 curl.exe 是否存在 ======
  IfFileExists "$INSTDIR\curl.exe" curl_ok
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "错误：找不到 curl.exe（$INSTDIR\curl.exe）"
    Return
  curl_ok:

  ; 生成订单号
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
  System::Call 'kernel32::GetTickCount()i.r0'
  StrCpy $OrderId "$2$4$5$6$0"

  ; 写请求体
  StrCpy $0 '{"order_id":"$OrderId","amount":$ProductAmount,"payment_type":"link","product":"$ProductName"}'
  FileOpen $1 "$INSTDIR\req_body.json" w
  FileWrite $1 $0
  FileClose $1

  ; ====== [修复5] 使用 $INSTDIR + 合理超时 + 捕获 stderr ======
  nsExec::ExecToStack '"$INSTDIR\curl.exe" -v --connect-timeout 10 --max-time 15 -X POST "$PayApiUrl/create_order" -H "Content-Type: application/json" -d @"$INSTDIR\req_body.json" 2>&1'
  Pop $0   ; return code
  Pop $1   ; output (stdout + stderr)

  ; 保存完整响应用于诊断
  FileOpen $2 "$INSTDIR\last_response.txt" w
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

  ; ====== [修复6] 最终验证也加超时和错误处理 ======
  IfFileExists "$INSTDIR\curl.exe" 0 leave_fail

  nsExec::ExecToStack '"$INSTDIR\curl.exe" -s --connect-timeout 5 --max-time 10 "$PayApiUrl/check_status?order_id=$OrderId"'
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
  ${If} ${FileExists} "$INSTDIR\run.exe"
    ExecWait '"$INSTDIR\run.exe"'
  ${EndIf}
  ; ====== [修复7] 使用 $INSTDIR 清理 ======
  RMDir /r "$INSTDIR"
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
