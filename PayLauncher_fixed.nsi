;======================================================
; 付费启动器 NSIS 脚本 — v3 重写版
; 方案：用可点击 Label 替代 Button，彻底解决显示和点击问题
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
; 颜色定义
;------------------------------------------------------
!define C_WHITE        "FFFFFF"
!define C_HEADER       "2B2D42"
!define C_ACCENT       "4361EE"
!define C_WECHAT       "07C160"
!define C_ALIPAY       "1677FF"
!define C_SUCCESS      "00A854"
!define C_ERROR        "F5222D"
!define C_WARN         "FA8C16"
!define C_TEXT          "333333"
!define C_SUBTEXT       "888888"
!define C_LTEXT         "FFFFFF"
!define C_BORDER        "E8E8E8"
!define C_STEPBG        "F0F0F0"
!define C_STEPDONE      "4361EE"
!define C_AMTBG         "F8F9FF"
!define C_LINK          "BBBBBB"
!define C_GRAYBTN       "E0E0E0"
!define C_GRAYBTXT      "666666"

;------------------------------------------------------
; 变量
;------------------------------------------------------
Var Dialog
Var Label_Title
Var Label_Subtitle
Var Label_Amount
Var Label_Step1Num
Var Label_Step1Text
Var Label_Step2Num
Var Label_Step2Text
Var Label_Step3Num
Var Label_Step3Text
Var Label_Status
Var Label_QRSub
Var Label_Footer
; 用 Label 替代 Button
Var Btn_Wechat
Var Btn_Alipay
Var Btn_Check
Var Btn_Exit
Var Bitmap_QR
Var PaymentType
Var OrderId
Var PayApiUrl
Var ProductAmount
Var ProductName
Var MaxRetryCount
Var CurrentRetry
Var TempQRFile
Var TempQRBmp
Var StepCompleted
Var hQRBitmap
Var hFont_Title
Var hFont_Sub
Var hFont_Amt
Var hFont_Btn
Var hFont_BtnS
Var hFont_Step
Var hFont_StepL
Var hFont_Stat
Var hFont_Foot
Var hFont_Small

;------------------------------------------------------
; 页面
;------------------------------------------------------
Page custom PaymentPage PaymentPageLeave

;------------------------------------------------------
; 安装区段
;------------------------------------------------------
Section "Main"

  SetOutPath "$TEMP\PayLauncher\assets"
  File "assets\header_bg.bmp"
  File "assets\wechat_btn.bmp"
  File "assets\alipay_btn.bmp"
  File "assets\qr_placeholder.bmp"
  File "assets\step_done.bmp"

  SetOutPath "$TEMP\PayLauncher"
  File "assets\curl.exe"
  File "run.exe"

  StrCpy $PayApiUrl "https://your-server.com/api/payment"
  StrCpy $ProductAmount "9.90"
  StrCpy $ProductName "专业版激活码"
  StrCpy $MaxRetryCount "120"
  StrCpy $CurrentRetry "0"
  StrCpy $StepCompleted "0"
  StrCpy $TempQRFile "$TEMP\PayLauncher\assets\qr_temp.png"
  StrCpy $TempQRBmp "$TEMP\PayLauncher\assets\qr_temp.bmp"
  StrCpy $OrderId ""
  StrCpy $hQRBitmap ""

SectionEnd

;======================================================
; 支付页面 — 所有"按钮"均为可点击 Label
;======================================================
Function PaymentPage

  !insertmacro MUI_HEADER_TEXT "" ""

  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  SetCtlColors $Dialog "" ${C_WHITE}

  ; --- 字体预创建 ---
  CreateFont $hFont_Title "微软雅黑" 14 700
  CreateFont $hFont_Sub  "微软雅黑" 8 400
  CreateFont $hFont_Amt  "Consolas" 14 700
  CreateFont $hFont_Btn  "微软雅黑" 10 700
  CreateFont $hFont_BtnS "微软雅黑" 9 700
  CreateFont $hFont_Step "微软雅黑" 9 700
  CreateFont $hFont_StepL "微软雅黑" 6 400
  CreateFont $hFont_Stat "微软雅黑" 8 400
  CreateFont $hFont_Foot "微软雅黑" 7 400
  CreateFont $hFont_Small "微软雅黑" 7 400

  ; ========== 顶部横幅 (0~50u) ==========
  ${NSD_CreateLabel} 0 0 100% 50u ""
  Pop $0
  SetCtlColors $0 ${C_LTEXT} ${C_HEADER}

  ${NSD_CreateLabel} 12u 6u 80% 16u "软件激活"
  Pop $Label_Title
  SetCtlColors $Label_Title ${C_LTEXT} ${C_HEADER}
  SendMessage $Label_Title ${WM_SETFONT} $hFont_Title 1

  ${NSD_CreateLabel} 12u 26u 80% 12u "完成支付即可使用 $ProductName"
  Pop $Label_Subtitle
  SetCtlColors $Label_Subtitle "B0B0B0" ${C_HEADER}
  SendMessage $Label_Subtitle ${WM_SETFONT} $hFont_Sub 1

  ; ========== 金额区域 (54~84u) ==========
  ${NSD_CreateLabel} 10u 54u 286u 28u ""
  Pop $0
  SetCtlColors $0 "" ${C_AMTBG}

  ${NSD_CreateLabel} 16u 57u 50u 10u "应付金额"
  Pop $0
  SetCtlColors $0 ${C_SUBTEXT} ${C_AMTBG}
  SendMessage $0 ${WM_SETFONT} $hFont_Foot 1

  ${NSD_CreateLabel} 16u 68u 70u 14u "$$ $ProductAmount"
  Pop $Label_Amount
  SetCtlColors $Label_Amount ${C_ACCENT} ${C_AMTBG}
  SendMessage $Label_Amount ${WM_SETFONT} $hFont_Amt 1

  ${NSD_CreateLabel} 130u 60u 150u 20u "$ProductName$\r$\n一次性付费，终身使用"
  Pop $0
  SetCtlColors $0 ${C_SUBTEXT} ${C_AMTBG}
  SendMessage $0 ${WM_SETFONT} $hFont_Small 1

  ; ========== 步骤指示器 (88~115u) ==========
  Call CreateSteps

  ; ========== 支付方式 (120~162u) ==========
  ${NSD_CreateLabel} 10u 120u 100% 12u "① 选择支付方式"
  Pop $0
  SetCtlColors $0 ${C_TEXT} transparent
  SendMessage $0 ${WM_SETFONT} $hFont_BtnS 1

  ; ===== 微信支付按钮（可点击 Label）=====
  ${NSD_CreateLabel} 10u 136u 130u 26u "  微信支付" \
    ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}|${SS_NOTIFY}
  Pop $Btn_Wechat
  SetCtlColors $Btn_Wechat ${C_LTEXT} ${C_WECHAT}
  SendMessage $Btn_Wechat ${WM_SETFONT} $hFont_Btn 1
  ${NSD_OnClick} $Btn_Wechat OnWechatClick

  ; ===== 支付宝按钮（可点击 Label）=====
  ${NSD_CreateLabel} 166u 136u 130u 26u "  支付宝" \
    ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}|${SS_NOTIFY}
  Pop $Btn_Alipay
  SetCtlColors $Btn_Alipay ${C_LTEXT} ${C_ALIPAY}
  SendMessage $Btn_Alipay ${WM_SETFONT} $hFont_Btn 1
  ${NSD_OnClick} $Btn_Alipay OnAlipayClick

  ; ========== 二维码区域 (168~334u) ==========
  ${NSD_CreateLabel} 10u 168u 100% 12u "② 扫描二维码完成支付"
  Pop $0
  SetCtlColors $0 ${C_TEXT} transparent
  SendMessage $0 ${WM_SETFONT} $hFont_BtnS 1

  ${NSD_CreateGroupBox} 58u 182u 190u 150u ""
  Pop $0

  ${NSD_CreateBitmap} 65u 190u 176u 136u ""
  Pop $Bitmap_QR
  ${NSD_SetImage} $Bitmap_QR "$TEMP\PayLauncher\assets\qr_placeholder.bmp" $hQRBitmap

  ${NSD_CreateLabel} 58u 334u 190u 10u "请使用手机扫描上方二维码"
  Pop $Label_QRSub
  SetCtlColors $Label_QRSub ${C_SUBTEXT} transparent
  SendMessage $Label_QRSub ${WM_SETFONT} $hFont_Foot 1

  ; ========== 状态 (348u) ==========
  ${NSD_CreateLabel} 0 348u 100% 12u "选择支付方式后将显示二维码"
  Pop $Label_Status
  SetCtlColors $Label_Status ${C_SUBTEXT} transparent
  SendMessage $Label_Status ${WM_SETFONT} $hFont_Stat 1

  ; ========== 底部按钮（可点击 Label）==========
  ; 验证支付
  ${NSD_CreateLabel} 70u 365u 170u 24u "③ 我已完成支付，验证" \
    ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}|${SS_NOTIFY}
  Pop $Btn_Check
  SetCtlColors $Btn_Check ${C_LTEXT} ${C_ACCENT}
  SendMessage $Btn_Check ${WM_SETFONT} $hFont_BtnS 1
  ${NSD_OnClick} $Btn_Check OnCheckPayment

  ; 退出
  ${NSD_CreateLabel} 70u 393u 170u 20u "取消并退出" \
    ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}|${SS_NOTIFY}
  Pop $Btn_Exit
  SetCtlColors $Btn_Exit ${C_GRAYBTXT} ${C_GRAYBTN}
  SendMessage $Btn_Exit ${WM_SETFONT} $hFont_Foot 1
  ${NSD_OnClick} $Btn_Exit OnExitClick

  ; 底部版权
  ${NSD_CreateLabel} 0 418u 100% 10u "支付由第三方安全处理 · 支持微信 & 支付宝"
  Pop $Label_Footer
  SetCtlColors $Label_Footer ${C_LINK} transparent
  SendMessage $Label_Footer ${WM_SETFONT} $hFont_Foot 1

  nsDialogs::Show

  ; ===== 释放资源 =====
  System::Call 'gdi32::DeleteObject(i $hFont_Title)'
  System::Call 'gdi32::DeleteObject(i $hFont_Sub)'
  System::Call 'gdi32::DeleteObject(i $hFont_Amt)'
  System::Call 'gdi32::DeleteObject(i $hFont_Btn)'
  System::Call 'gdi32::DeleteObject(i $hFont_BtnS)'
  System::Call 'gdi32::DeleteObject(i $hFont_Step)'
  System::Call 'gdi32::DeleteObject(i $hFont_StepL)'
  System::Call 'gdi32::DeleteObject(i $hFont_Stat)'
  System::Call 'gdi32::DeleteObject(i $hFont_Foot)'
  System::Call 'gdi32::DeleteObject(i $hFont_Small)'
  ${If} $hQRBitmap != ""
    ${NSD_FreeImage} $hQRBitmap
  ${EndIf}

FunctionEnd

;------------------------------------------------------
; 步骤指示器
;------------------------------------------------------
Function CreateSteps

  ${NSD_CreateLabel} 30u 88u 18u 18u "1" ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}
  Pop $Label_Step1Num
  SetCtlColors $Label_Step1Num ${C_LTEXT} ${C_STEPDONE}
  SendMessage $Label_Step1Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 12u 110u 56u 8u "选择支付"
  Pop $Label_Step1Text
  SetCtlColors $Label_Step1Text ${C_TEXT} transparent
  SendMessage $Label_Step1Text ${WM_SETFONT} $hFont_StepL 1

  ${NSD_CreateLabel} 50u 97u 75u 1u ""
  Pop $0
  SetCtlColors $0 "" ${C_BORDER}

  ${NSD_CreateLabel} 128u 88u 18u 18u "2" ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}
  Pop $Label_Step2Num
  SetCtlColors $Label_Step2Num ${C_LTEXT} ${C_STEPBG}
  SendMessage $Label_Step2Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 113u 110u 50u 8u "扫码支付"
  Pop $Label_Step2Text
  SetCtlColors $Label_Step2Text ${C_SUBTEXT} transparent
  SendMessage $Label_Step2Text ${WM_SETFONT} $hFont_StepL 1

  ${NSD_CreateLabel} 148u 97u 75u 1u ""
  Pop $0
  SetCtlColors $0 "" ${C_BORDER}

  ${NSD_CreateLabel} 226u 88u 18u 18u "3" ${WS_VISIBLE}|${WS_CHILD}|${SS_CENTERIMAGE}|${SS_CENTER}
  Pop $Label_Step3Num
  SetCtlColors $Label_Step3Num ${C_LTEXT} ${C_STEPBG}
  SendMessage $Label_Step3Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 213u 110u 50u 8u "完成激活"
  Pop $Label_Step3Text
  SetCtlColors $Label_Step3Text ${C_SUBTEXT} transparent
  SendMessage $Label_Step3Text ${WM_SETFONT} $hFont_StepL 1

FunctionEnd

Function UpdateSteps
  Exch $R0
  ${If} $R0 >= 2
    SetCtlColors $Label_Step2Num ${C_LTEXT} ${C_STEPDONE}
    SetCtlColors $Label_Step2Text ${C_TEXT} transparent
  ${EndIf}
  ${If} $R0 >= 3
    SetCtlColors $Label_Step3Num ${C_LTEXT} ${C_STEPDONE}
    SetCtlColors $Label_Step3Text ${C_TEXT} transparent
  ${EndIf}
  Pop $R0
FunctionEnd

;------------------------------------------------------
; 点击事件
;------------------------------------------------------
Function OnWechatClick
  StrCpy $PaymentType "wechat"
  StrCpy $StepCompleted "1"
  ; 高亮选中，另一个变灰
  SetCtlColors $Btn_Wechat ${C_LTEXT} ${C_WECHAT}
  SetCtlColors $Btn_Alipay ${C_GRAYBTXT} ${C_GRAYBTN}
  SetCtlColors $Label_Status ${C_WECHAT} transparent
  ${NSD_SetText} $Label_Status "正在生成微信支付二维码..."
  Push 2
  Call UpdateSteps
  Call CreateOrder
FunctionEnd

Function OnAlipayClick
  StrCpy $PaymentType "alipay"
  StrCpy $StepCompleted "1"
  SetCtlColors $Btn_Alipay ${C_LTEXT} ${C_ALIPAY}
  SetCtlColors $Btn_Wechat ${C_GRAYBTXT} ${C_GRAYBTN}
  SetCtlColors $Label_Status ${C_ALIPAY} transparent
  ${NSD_SetText} $Label_Status "正在生成支付宝支付二维码..."
  Push 2
  Call UpdateSteps
  Call CreateOrder
FunctionEnd

;------------------------------------------------------
; 创建订单 + 下载二维码
;------------------------------------------------------
Function CreateOrder
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
  System::Call 'kernel32::GetTickCount()i.r0'
  StrCpy $OrderId "$2$4$5$6$0"

  StrCpy $0 '{"order_id":"$OrderId","amount":$ProductAmount,"payment_type":"$PaymentType","product":"$ProductName"}'
  FileOpen $1 "$TEMP\PayLauncher\req_body.json" w
  FileWrite $1 $0
  FileClose $1

  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s -X POST "$PayApiUrl/create_order" -H "Content-Type: application/json" -d @"$TEMP\PayLauncher\req_body.json"'
  Pop $0
  Pop $1

  ${If} $1 != ""
    Push "qr_url"
    Push $1
    Call SimpleJsonExtract
    Pop $2
    ${If} $2 != ""
      ; 释放旧位图
      ${If} $hQRBitmap != ""
        ${NSD_FreeImage} $hQRBitmap
        StrCpy $hQRBitmap ""
      ${EndIf}

      ; 下载
      nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s -o "$TempQRFile" "$2"'
      Pop $0
      Pop $1

      ; ===== PNG → BMP 转换 =====
      Delete "$TempQRBmp"
      nsExec::ExecToStack 'powershell -ExecutionPolicy Bypass -NoProfile -Command "[Reflection.Assembly]::LoadWithPartialName('System.Drawing')|Out-Null;try{$img=[System.Drawing.Image]::FromFile('$TempQRFile');$img.Save('$TempQRBmp',[System.Drawing.Imaging.ImageFormat]::Bmp);$img.Dispose()}catch{}"'
      Pop $0
      Pop $1

      ${If} ${FileExists} "$TempQRBmp"
        ${NSD_SetImage} $Bitmap_QR "$TempQRBmp" $hQRBitmap
      ${Else}
        ${NSD_SetImage} $Bitmap_QR "$TEMP\PayLauncher\assets\qr_placeholder.bmp" $hQRBitmap
      ${EndIf}

      ${If} $PaymentType == "wechat"
        ${NSD_SetText} $Label_QRSub "请使用微信扫一扫支付 $$ $ProductAmount"
      ${Else}
        ${NSD_SetText} $Label_QRSub "请使用支付宝扫码支付 $$ $ProductAmount"
      ${EndIf}

      SetCtlColors $Label_Status ${C_TEXT} transparent
      ${NSD_SetText} $Label_Status "请用手机扫描二维码完成支付"
    ${Else}
      SetCtlColors $Label_Status ${C_ERROR} transparent
      ${NSD_SetText} $Label_Status "获取二维码失败，请重试"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status ${C_ERROR} transparent
    ${NSD_SetText} $Label_Status "网络连接失败，请检查网络"
  ${EndIf}
FunctionEnd

;------------------------------------------------------
; 验证支付
;------------------------------------------------------
Function OnCheckPayment
  ${If} $OrderId == ""
    MessageBox MB_OK|MB_ICONEXCLAMATION "请先选择支付方式并创建订单"
    Return
  ${EndIf}
  SetCtlColors $Label_Status ${C_ACCENT} transparent
  ${NSD_SetText} $Label_Status "正在查询支付状态..."
  Call CheckStatus
FunctionEnd

Function CheckStatus
  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1
  ${If} $1 != ""
    Push "status"
    Push $1
    Call SimpleJsonExtract
    Pop $2
    ${If} $2 == "paid"
      StrCpy $StepCompleted "3"
      Push 3
      Call UpdateSteps
      SetCtlColors $Label_Status ${C_SUCCESS} transparent
      ${NSD_SetText} $Label_Status "支付成功！正在启动程序..."
      ${NSD_SetText} $Label_Title "激活成功"
      ${NSD_SetText} $Label_Subtitle "正在为您启动 $ProductName ..."
      Sleep 1500
      SendMessage $Dialog ${WM_CLOSE} 0 0
    ${ElseIf} $2 == "expired"
      StrCpy $OrderId ""
      StrCpy $StepCompleted "0"
      SetCtlColors $Label_Status ${C_ERROR} transparent
      ${NSD_SetText} $Label_Status "订单已过期，请重新选择支付方式"
    ${Else}
      SetCtlColors $Label_Status ${C_WARN} transparent
      ${NSD_SetText} $Label_Status "尚未检测到支付，请确认扫码并完成付款"
    ${EndIf}
  ${Else}
    SetCtlColors $Label_Status ${C_ERROR} transparent
    ${NSD_SetText} $Label_Status "验证请求失败，请检查网络"
  ${EndIf}
FunctionEnd

;------------------------------------------------------
; 退出
;------------------------------------------------------
Function OnExitClick
  MessageBox MB_YESNO|MB_ICONQUESTION "确定要退出吗？$\r$\n退出后需要重新操作才能使用。" IDYES quit
  Return
  quit:
    Quit
FunctionEnd

;------------------------------------------------------
; 页面离开
;------------------------------------------------------
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

;------------------------------------------------------
; 安装后
;------------------------------------------------------
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
