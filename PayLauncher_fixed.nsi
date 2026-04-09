;======================================================
; 付费启动器 — v6 自动打开支付 + 纯文字界面
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

Var Dialog
Var Label_Info
Var Label_Status
Var Btn_Check
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

Function PayPage
  !insertmacro MUI_HEADER_TEXT "" ""

  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  CreateFont $hFont1 "微软雅黑" 11 700
  CreateFont $hFont2 "微软雅黑" 10 400

  ; --- 提示文字 ---
  ${NSD_CreateLabel} 0 20u 100% 40u "正在打开支付页面...$\r$\n$\r$\n请在浏览器中完成支付，然后回到这里点击验证。"
  Pop $Label_Info
  SetCtlColors $Label_Info "333333" transparent
  SendMessage $Label_Info ${WM_SETFONT} $hFont2 1

  ; --- 状态 ---
  ${NSD_CreateLabel} 0 70u 100% 14u "正在创建订单..."
  Pop $Label_Status
  SetCtlColors $Label_Status "4361EE" transparent
  SendMessage $Label_Status ${WM_SETFONT} $hFont1 1

  ; --- 验证按钮 ---
  ${NSD_CreateLabel} 40u 100u 230u 28u "验证支付状态"
  Pop $Btn_Check
  SetCtlColors $Btn_Check "FFFFFF" "00A854"
  SendMessage $Btn_Check ${WM_SETFONT} $hFont1 1
  ${NSD_OnClick} $Btn_Check OnCheck

  ; --- 退出按钮 ---
  ${NSD_CreateLabel} 110u 140u 90u 22u "退出"
  Pop $Btn_Exit
  SetCtlColors $Btn_Exit "999999" "F0F0F0"
  SendMessage $Btn_Exit ${WM_SETFONT} $hFont2 1
  ${NSD_OnClick} $Btn_Exit OnExit

  ; ===== 自动创建订单并打开浏览器 =====
  Call AutoCreateOrder

  nsDialogs::Show

  System::Call 'gdi32::DeleteObject(i $hFont1)'
  System::Call 'gdi32::DeleteObject(i $hFont2)'
FunctionEnd

;======================================================
; 自动创建订单 + 打开支付页面
;======================================================
Function AutoCreateOrder
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
  System::Call 'kernel32::GetTickCount()i.r0'
  StrCpy $OrderId "$2$4$5$6$0"

  StrCpy $0 '{"order_id":"$OrderId","amount":$ProductAmount,"payment_type":"link","product":"$ProductName"}'
  FileOpen $1 "$TEMP\PayLauncher\req_body.json" w
  FileWrite $1 $0
  FileClose $1

  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s -X POST "$PayApiUrl/create_order" -H "Content-Type: application/json" -d @"$TEMP\PayLauncher\req_body.json"'
  Pop $0
  Pop $1

  ${If} $1 != ""
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
      ${NSD_SetText} $Label_Status "已打开支付页面，请扫码支付"
    ${Else}
      SetCtlColors $Label_Status "F5222D" transparent
      ${NSD_SetText} $Label_Status "创建订单失败"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "网络连接失败"
  ${EndIf}
FunctionEnd

;======================================================
; 验证
;======================================================
Function OnCheck
  ${If} $OrderId == ""
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "订单不存在，请重启程序"
    Return
  ${EndIf}

  SetCtlColors $Label_Status "4361EE" transparent
  ${NSD_SetText} $Label_Status "正在查询..."

  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2
    ${If} $2 == "paid"
      SetCtlColors $Label_Status "00A854" transparent
      ${NSD_SetText} $Label_Status "支付成功，正在启动..."
      Sleep 1500
      SendMessage $Dialog ${WM_CLOSE} 0 0
    ${ElseIf} $2 == "expired"
      StrCpy $OrderId ""
      StrCpy $PayPageUrl ""
      SetCtlColors $Label_Status "F5222D" transparent
      ${NSD_SetText} $Label_Status "订单已过期，请重启程序"
    ${Else}
      SetCtlColors $Label_Status "FA8C16" transparent
      ${NSD_SetText} $Label_Status "尚未支付，请在浏览器中完成支付"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "网络请求失败"
  ${EndIf}
FunctionEnd

Function OnExit
  MessageBox MB_YESNO "确定退出？" IDYES +2
  Return
  Quit
FunctionEnd

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
