;======================================================
; 付费启动器 NSIS 脚本 — v4 链接支付版
; 方案：NSIS 只做 3 件事 → 显示信息、打开支付网页、轮询验证
; 支付页面由后端 Web 提供，彻底告别 NSIS UI 局限
;======================================================

!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "WinMessages.nsh"
!include "FileFunc.nsh"
!include "WinCore.nsh"

!pragma warning disable 6001

;------------------------------------------------------
; 基本配置
;------------------------------------------------------
Name "软件激活"
OutFile "PayLauncher.exe"
InstallDir "$TEMP\PayLauncher"
RequestExecutionLevel user
ShowInstDetails nevershow

!define MUI_WELCOMEFINISHPAGE_BITMAP_NOSTRETCH

;------------------------------------------------------
; 变量
;------------------------------------------------------
Var Dialog
Var Label_Title
Var Label_Amount
Var Label_Product
Var Label_Status
Var Btn_Pay
Var Btn_Check
Var Btn_Exit
Var OrderId
Var PayApiUrl
Var PayPageUrl       ; 支付网页地址
Var ProductAmount
Var ProductName
Var StepCompleted    ; 0=初始 1=已打开网页 2=已支付
Var hFont_Title
Var hFont_Body
Var hFont_Amount
Var hFont_Btn
Var hFont_Status

;------------------------------------------------------
; 页面
;------------------------------------------------------
Page custom PaymentPage PaymentPageLeave

;------------------------------------------------------
; 安装区段
;------------------------------------------------------
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
; 极简支付页面 — 3 个按钮，零图片依赖
;======================================================
Function PaymentPage

  !insertmacro MUI_HEADER_TEXT "" ""

  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  SetCtlColors $Dialog "" "FFFFFF"

  ; 字体
  CreateFont $hFont_Title "微软雅黑" 14 700
  CreateFont $hFont_Body  "微软雅黑" 9 400
  CreateFont $hFont_Amount "Consolas" 16 700
  CreateFont $hFont_Btn  "微软雅黑" 10 700
  CreateFont $hFont_Status "微软雅黑" 9 400

  ; ===== 标题 =====
  ${NSD_CreateLabel} 0 20u 100% 18u "软件激活"
  Pop $Label_Title
  SetCtlColors $Label_Title "333333" transparent
  SendMessage $Label_Title ${WM_SETFONT} $hFont_Title 1

  ; ===== 分隔线 =====
  ${NSD_CreateLabel} 40u 42u 226u 1u ""
  Pop $0
  SetCtlColors $0 "" "E8E8E8"

  ; ===== 产品名 =====
  ${NSD_CreateLabel} 0 52u 100% 12u "$ProductName"
  Pop $Label_Product
  SetCtlColors $Label_Product "888888" transparent
  SendMessage $Label_Product ${WM_SETFONT} $hFont_Body 1

  ; ===== 金额 =====
  ${NSD_CreateLabel} 0 70u 100% 20u "$$ $ProductAmount"
  Pop $Label_Amount
  SetCtlColors $Label_Amount "4361EE" transparent
  SendMessage $Label_Amount ${WM_SETFONT} $hFont_Amount 1

  ; ===== 提示 =====
  ${NSD_CreateLabel} 0 98u 100% 10u "点击下方按钮，在浏览器中完成支付"
  Pop $0
  SetCtlColors $0 "888888" transparent
  SendMessage $0 ${WM_SETFONT} $hFont_Body 1

  ; ===== [打开支付页面] 按钮（可点击 Label）=====
  ${NSD_CreateLabel} 50u 118u 210u 30u "  打开支付页面" \
    ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}|${SS_NOTIFY}
  Pop $Btn_Pay
  SetCtlColors $Btn_Pay "FFFFFF" "4361EE"
  SendMessage $Btn_Pay ${WM_SETFONT} $hFont_Btn 1
  ${NSD_OnClick} $Btn_Pay OnOpenPayPage

  ; ===== 分隔线 =====
  ${NSD_CreateLabel} 40u 160u 226u 1u ""
  Pop $0
  SetCtlColors $0 "" "E8E8E8"

  ; ===== 说明 =====
  ${NSD_CreateLabel} 0 170u 100% 10u "支付完成后，回到这里点击验证"
  Pop $0
  SetCtlColors $0 "666666" transparent
  SendMessage $0 ${WM_SETFONT} $hFont_Body 1

  ; ===== [我已完成支付] 按钮（可点击 Label）=====
  ${NSD_CreateLabel} 50u 188u 210u 28u "  我已完成支付，验证" \
    ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}|${SS_NOTIFY}
  Pop $Btn_Check
  SetCtlColors $Btn_Check "FFFFFF" "00A854"
  SendMessage $Btn_Check ${WM_SETFONT} $hFont_Btn 1
  ${NSD_OnClick} $Btn_Check OnCheckPayment

  ; ===== 状态 =====
  ${NSD_CreateLabel} 0 226u 100% 12u ""
  Pop $Label_Status
  SetCtlColors $Label_Status "888888" transparent
  SendMessage $Label_Status ${WM_SETFONT} $hFont_Status 1

  ; ===== [退出] 按钮（可点击 Label）=====
  ${NSD_CreateLabel} 110u 248u 90u 22u "取消并退出" \
    ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}|${SS_NOTIFY}
  Pop $Btn_Exit
  SetCtlColors $Btn_Exit "999999" "F0F0F0"
  SendMessage $Btn_Exit ${WM_SETFONT} $hFont_Body 1
  ${NSD_OnClick} $Btn_Exit OnExitClick

  nsDialogs::Show

  ; 释放字体
  System::Call 'gdi32::DeleteObject(i $hFont_Title)'
  System::Call 'gdi32::DeleteObject(i $hFont_Body)'
  System::Call 'gdi32::DeleteObject(i $hFont_Amount)'
  System::Call 'gdi32::DeleteObject(i $hFont_Btn)'
  System::Call 'gdi32::DeleteObject(i $hFont_Status)'

FunctionEnd

;======================================================
; 打开支付页面 — 创建订单 → 打开浏览器
;======================================================
Function OnOpenPayPage

  ; 已有订单则直接打开
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

  ; 构造请求
  StrCpy $0 '{"order_id":"$OrderId","amount":$ProductAmount,"payment_type":"link","product":"$ProductName"}'
  FileOpen $1 "$TEMP\PayLauncher\req_body.json" w
  FileWrite $1 $0
  FileClose $1

  ; 调用后端创建订单
  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s -X POST "$PayApiUrl/create_order" -H "Content-Type: application/json" -d @"$TEMP\PayLauncher\req_body.json"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    ; 提取支付页面 URL
    Push "pay_url"
    Push $1
    Call SimpleJsonExtract
    Pop $2

    ${If} $2 == ""
      ; 兼容：尝试 qr_url 字段
      Push "qr_url"
      Push $1
      Call SimpleJsonExtract
      Pop $2
    ${EndIf}

    ${If} $2 != ""
      StrCpy $PayPageUrl "$2"
      ; 用系统默认浏览器打开
      ExecShell "open" "$PayPageUrl"
      StrCpy $StepCompleted "1"

      SetCtlColors $Label_Status "00A854" transparent
      ${NSD_SetText} $Label_Status "已在浏览器中打开支付页面，完成支付后回来验证"
    ${Else}
      SetCtlColors $Label_Status "F5222D" transparent
      ${NSD_SetText} $Label_Status "创建订单失败：服务器未返回支付链接"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "网络连接失败，请检查网络"
  ${EndIf}

FunctionEnd

;======================================================
; 验证支付
;======================================================
Function OnCheckPayment
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
      ${NSD_SetText} $Label_Status "支付成功！正在启动程序..."
      ${NSD_SetText} $Label_Title "激活成功"
      Sleep 1500
      SendMessage $Dialog ${WM_CLOSE} 0 0
    ${ElseIf} $2 == "expired"
      StrCpy $OrderId ""
      StrCpy $PayPageUrl ""
      StrCpy $StepCompleted "0"
      SetCtlColors $Label_Status "F5222D" transparent
      ${NSD_SetText} $Label_Status "订单已过期，请重新点击「打开支付页面」"
    ${Else}
      SetCtlColors $Label_Status "FA8C16" transparent
      ${NSD_SetText} $Label_Status "尚未检测到支付，请在浏览器中完成支付后再验证"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status "F5222D" transparent
    ${NSD_SetText} $Label_Status "验证请求失败，请检查网络"
  ${EndIf}
FunctionEnd

;======================================================
; 退出
;======================================================
Function OnExitClick
  MessageBox MB_YESNO|MB_ICONQUESTION "确定要退出吗？$\r$\n退出后需要重新操作才能使用。" IDYES quit
  Return
  quit:
    Quit
FunctionEnd

;======================================================
; 页面离开
;======================================================
Function PaymentPageLeave
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
      MessageBox MB_OK|MB_ICONEXCLAMATION "支付尚未完成，请先完成支付后再继续。"
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
