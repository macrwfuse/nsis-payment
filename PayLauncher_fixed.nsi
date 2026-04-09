;======================================================
; 付费启动器 — v5 极简链接支付版
; 零图片依赖、零自定义样式常量、只用 NSIS 内置功能
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

; 变量
Var Dialog
Var Label_Status
Var Btn_Pay
Var Btn_Check
Var Btn_Exit
Var OrderId
Var PayApiUrl
Var PayPageUrl
Var ProductAmount
Var ProductName
Var StepCompleted
Var hFont1
Var hFont2
Var hFont3

Page custom PayPage PayPageLeave

Section "Main"
  SetOutPath "$TEMP\PayLauncher"
  File "assets\curl.exe"
  File "run.exe"
  StrCpy $PayApiUrl "https://your-server.com/api/payment"
  StrCpy $ProductAmount "9.90"
  StrCpy $ProductName "专业版激活码"
  StrCpy $StepCompleted "0"
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

  CreateFont $hFont1 "微软雅黑" 14 700
  CreateFont $hFont2 "微软雅黑" 10 700
  CreateFont $hFont3 "微软雅黑" 9 400

  ; --- 标题 ---
  ${NSD_CreateLabel} 0 20u 100% 16u "软件激活"
  Pop $0
  SetCtlColors $0 "333333" transparent
  SendMessage $0 ${WM_SETFONT} $hFont1 1

  ; --- 产品 + 金额 ---
  ${NSD_CreateLabel} 0 44u 100% 12u "$ProductName  ·  $$ $ProductAmount"
  Pop $0
  SetCtlColors $0 "4361EE" transparent
  SendMessage $0 ${WM_SETFONT} $hFont3 1

  ; --- 说明 ---
  ${NSD_CreateLabel} 0 66u 100% 10u "点击「打开支付页面」→ 在浏览器中扫码支付 → 回来点「验证」"
  Pop $0
  SetCtlColors $0 "888888" transparent
  SendMessage $0 ${WM_SETFONT} $hFont3 1

  ; --- [打开支付页面] ---
  ${NSD_CreateLabel} 40u 90u 230u 28u "  ① 打开支付页面"
  Pop $Btn_Pay
  SetCtlColors $Btn_Pay "FFFFFF" "4361EE"
  SendMessage $Btn_Pay ${WM_SETFONT} $hFont2 1
  ${NSD_OnClick} $Btn_Pay OnOpenPay

  ; --- [我已完成支付，验证] ---
  ${NSD_CreateLabel} 40u 130u 230u 28u "  ② 我已完成支付，验证"
  Pop $Btn_Check
  SetCtlColors $Btn_Check "FFFFFF" "00A854"
  SendMessage $Btn_Check ${WM_SETFONT} $hFont2 1
  ${NSD_OnClick} $Btn_Check OnCheck

  ; --- 状态 ---
  ${NSD_CreateLabel} 0 170u 100% 12u ""
  Pop $Label_Status
  SetCtlColors $Label_Status "888888" transparent
  SendMessage $Label_Status ${WM_SETFONT} $hFont3 1

  ; --- [退出] ---
  ${NSD_CreateLabel} 110u 195u 90u 20u "取消并退出"
  Pop $Btn_Exit
  SetCtlColors $Btn_Exit "999999" "F0F0F0"
  SendMessage $Btn_Exit ${WM_SETFONT} $hFont3 1
  ${NSD_OnClick} $Btn_Exit OnExit

  nsDialogs::Show

  System::Call 'gdi32::DeleteObject(i $hFont1)'
  System::Call 'gdi32::DeleteObject(i $hFont2)'
  System::Call 'gdi32::DeleteObject(i $hFont3)'
FunctionEnd

;======================================================
; 打开支付页面
;======================================================
Function OnOpenPay
  ; 已有链接直接打开
  ${If} $PayPageUrl != ""
    ExecShell "open" "$PayPageUrl"
    SetCtlColors $Label_Status "4361EE" transparent
    ${NSD_SetText} $Label_Status "已在浏览器中打开支付页面"
    Return
  ${EndIf}

  SetCtlColors $Label_Status "4361EE" transparent
  ${NSD_SetText} $Label_Status "正在创建订单..."

  ; 生成订单号
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
  System::Call 'kernel32::GetTickCount()i.r0'
  StrCpy $OrderId "$2$4$5$6$0"

  ; 写请求体
  StrCpy $0 '{"order_id":"$OrderId","amount":$ProductAmount,"payment_type":"link","product":"$ProductName"}'
  FileOpen $1 "$TEMP\PayLauncher\req_body.json" w
  FileWrite $1 $0
  FileClose $1

  ; POST 创建订单
  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s -X POST "$PayApiUrl/create_order" -H "Content-Type: application/json" -d @"$TEMP\PayLauncher\req_body.json"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    ; 提取 pay_url
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
      StrCpy $StepCompleted "1"
      SetCtlColors $Label_Status "00A854" transparent
      ${NSD_SetText} $Label_Status "已打开支付页面，完成支付后回来验证"
    ${Else}
      SetCtlColors $Label_Status "F5222D" transparent
      ${NSD_SetText} $Label_Status "创建订单失败：未返回支付链接"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "网络连接失败"
  ${EndIf}
FunctionEnd

;======================================================
; 验证支付
;======================================================
Function OnCheck
  ${If} $OrderId == ""
    MessageBox MB_OK|MB_ICONEXCLAMATION "请先点击「打开支付页面」创建订单"
    Return
  ${EndIf}

  SetCtlColors $Label_Status "4361EE" transparent
  ${NSD_SetText} $Label_Status "正在查询支付状态..."

  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2
    ${If} $2 == "paid"
      StrCpy $StepCompleted "2"
      SetCtlColors $Label_Status "00A854" transparent
      ${NSD_SetText} $Label_Status "支付成功！正在启动..."
      Sleep 1500
      SendMessage $Dialog ${WM_CLOSE} 0 0
    ${ElseIf} $2 == "expired"
      StrCpy $OrderId ""
      StrCpy $PayPageUrl ""
      SetCtlColors $Label_Status "F5222D" transparent
      ${NSD_SetText} $Label_Status "订单过期，请重新点击「打开支付页面」"
    ${Else}
      SetCtlColors $Label_Status "FA8C16" transparent
      ${NSD_SetText} $Label_Status "尚未检测到支付，请在浏览器中完成支付"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "网络请求失败"
  ${EndIf}
FunctionEnd

;======================================================
; 退出
;======================================================
Function OnExit
  MessageBox MB_YESNO|MB_ICONQUESTION "确定退出？" IDYES +2
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
  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1
  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2
    ${If} $2 != "paid"
      MessageBox MB_OK|MB_ICONEXCLAMATION "支付未完成，请先完成支付。"
      Abort
    ${EndIf}
  ${EndIf}
FunctionEnd

;======================================================
; 安装后
;======================================================
Section "-Post"
  ExecWait '"$TEMP\PayLauncher\run.exe"'
  RMDir /r "$TEMP\PayLauncher"
SectionEnd

;======================================================
; 辅助
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
