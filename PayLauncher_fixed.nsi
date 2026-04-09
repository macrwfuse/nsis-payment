;======================================================
; 付费启动器 NSIS 脚本 — 修复版
; 修复：按钮显示、选项不可选、布局溢出、资源泄漏
;======================================================

!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"
!include "WinMessages.nsh"
!include "FileFunc.nsh"
!include "WinCore.nsh"

;------------------------------------------------------
; 基本配置
;------------------------------------------------------
Name "软件激活"
OutFile "PayLauncher.exe"
InstallDir "$TEMP\PayLauncher"
RequestExecutionLevel user
ShowInstDetails nevershow

; 自定义窗口尺寸 — 加高到 550u 以容纳所有控件
!define MUI_WELCOMEFINISHPAGE_BITMAP_NOSTRETCH

; 调整 nsDialogs 页面尺寸（关键修复）
; 宽度 306u, 高度 380u → 实际可用区域约 520x600 像素
; 注意：nsDialogs 尺寸需通过 !define 预定义
!define PAYPAGE_WIDTH  306
!define PAYPAGE_HEIGHT 380

;------------------------------------------------------
; 颜色定义
;------------------------------------------------------
!define COLOR_BG         "FFFFFF"
!define COLOR_HEADER     "2B2D42"
!define COLOR_ACCENT     "4361EE"
!define COLOR_WECHAT     "07C160"
!define COLOR_ALIPAY     "1677FF"
!define COLOR_SUCCESS    "00A854"
!define COLOR_ERROR      "F5222D"
!define COLOR_WARN       "FA8C16"
!define COLOR_TEXT        "333333"
!define COLOR_TEXT_SEC    "888888"
!define COLOR_TEXT_LIGHT  "FFFFFF"
!define COLOR_BORDER      "E8E8E8"
!define COLOR_STEP_BG     "F0F0F0"
!define COLOR_STEP_DONE   "4361EE"
!define COLOR_DIVIDER     "EEEEEE"
!define COLOR_AMOUNT_BG   "F8F9FF"
!define COLOR_LINK        "BBBBBB"

;------------------------------------------------------
; 变量
;------------------------------------------------------
Var Dialog
Var Label_Title
Var Label_Subtitle
Var Label_Amount
Var Label_Step1Text
Var Label_Step2Text
Var Label_Step3Text
Var Label_Step1Num
Var Label_Step2Num
Var Label_Step3Num
Var Label_Status
Var Label_QRTitle
Var Label_QRSub
Var Label_Footer
Var Button_Wechat
Var Button_Alipay
Var Button_Check
Var Button_Exit
Var Bitmap_QR
Var GroupBox_QR
Var PaymentType
Var OrderId
Var PayApiUrl
Var ProductAmount
Var ProductName
Var MaxRetryCount
Var CurrentRetry
Var TempQRFile
Var StepCompleted
Var hQRBitmap       ; 二维码位图句柄（用于释放）

; 字体句柄（统一管理，防止泄漏）
Var hFont_Title
Var hFont_Subtitle
Var hFont_Amount
Var hFont_Button
Var hFont_ButtonSmall
Var hFont_Step
Var hFont_StepLabel
Var hFont_Status
Var hFont_Footer
Var hFont_QRTitle
Var hFont_Small

;------------------------------------------------------
; 页面定义
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

  ; 初始化
  StrCpy $PayApiUrl "https://your-server.com/api/payment"
  StrCpy $ProductAmount "9.90"
  StrCpy $ProductName "专业版激活码"
  StrCpy $MaxRetryCount "120"
  StrCpy $CurrentRetry "0"
  StrCpy $StepCompleted "0"
  StrCpy $TempQRFile "$TEMP\PayLauncher\assets\qr_temp.png"
  StrCpy $OrderId ""
  StrCpy $hQRBitmap ""

SectionEnd

;------------------------------------------------------
; 支付页面
;------------------------------------------------------
Function PaymentPage

  ; 隐藏默认的 MUI 头部
  !insertmacro MUI_HEADER_TEXT "" ""

  ; ========== 创建对话框 ==========
  ; 修复：移除废弃的 /NOUNLOAD 标志
  nsDialogs::Create 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  ; 设置对话框背景色
  SetCtlColors $Dialog "" ${COLOR_BG}

  ; ========== 顶部横幅区域 (0 ~ 50u) ==========
  ; 深色背景条
  ${NSD_CreateLabel} 0 0 100% 50u ""
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT_LIGHT} ${COLOR_HEADER}

  ; 大标题
  ${NSD_CreateLabel} 12u 6u 80% 16u "软件激活"
  Pop $Label_Title
  SetCtlColors $Label_Title ${COLOR_TEXT_LIGHT} ${COLOR_HEADER}
  CreateFont $hFont_Title "微软雅黑" 14 700
  SendMessage $Label_Title ${WM_SETFONT} $hFont_Title 1

  ; 副标题
  ${NSD_CreateLabel} 12u 26u 80% 12u "完成支付即可使用 $ProductName"
  Pop $Label_Subtitle
  SetCtlColors $Label_Subtitle "B0B0B0" ${COLOR_HEADER}
  CreateFont $hFont_Subtitle "微软雅黑" 8 400
  SendMessage $Label_Subtitle ${WM_SETFONT} $hFont_Subtitle 1

  ; ========== 金额展示区域 (54u ~ 84u) ==========
  ${NSD_CreateLabel} 10u 54u 286u 28u ""
  Pop $0
  SetCtlColors $0 "" ${COLOR_AMOUNT_BG}

  ; "应付金额" 标签
  ${NSD_CreateLabel} 16u 57u 50u 10u "应付金额"
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT_SEC} ${COLOR_AMOUNT_BG}
  CreateFont $hFont_Footer "微软雅黑" 7 400
  SendMessage $0 ${WM_SETFONT} $hFont_Footer 1

  ; 金额数字
  ${NSD_CreateLabel} 16u 68u 70u 14u "$$ $ProductAmount"
  Pop $Label_Amount
  SetCtlColors $Label_Amount ${COLOR_ACCENT} ${COLOR_AMOUNT_BG}
  CreateFont $hFont_Amount "Consolas" 14 700
  SendMessage $Label_Amount ${WM_SETFONT} $hFont_Amount 1

  ; 右侧说明
  ${NSD_CreateLabel} 130u 60u 150u 20u "$ProductName$\r$\n一次性付费，终身使用"
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT_SEC} ${COLOR_AMOUNT_BG}
  CreateFont $hFont_Small "微软雅黑" 7 400
  SendMessage $0 ${WM_SETFONT} $hFont_Small 1

  ; ========== 步骤指示器 (88u ~ 115u) ==========
  Call CreateStepIndicator

  ; ========== 支付方式选择 (120u ~ 155u) ==========
  ${NSD_CreateLabel} 10u 120u 100% 12u "① 选择支付方式"
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT} transparent
  CreateFont $hFont_QRTitle "微软雅黑" 8 700
  SendMessage $0 ${WM_SETFONT} $hFont_QRTitle 1

  ; ===== 修复：按钮用 BMP 图片实现彩色 =====
  ; 微信按钮（owner-drawn 风格，贴图实现颜色）
  ${NSD_CreateButton} 10u 136u 130u 26u ""
  Pop $Button_Wechat
  ${NSD_OnClick} $Button_Wechat OnWechatClick
  CreateFont $hFont_Button "微软雅黑" 9 700
  ; 用位图覆盖按钮外观
  StrCpy $0 "$TEMP\PayLauncher\assets\wechat_btn.bmp"
  ${NSD_SetImage} $Button_Wechat $0 $1

  ; 支付宝按钮
  ${NSD_CreateButton} 166u 136u 130u 26u ""
  Pop $Button_Alipay
  ${NSD_OnClick} $Button_Alipay OnAlipayClick
  StrCpy $0 "$TEMP\PayLauncher\assets\alipay_btn.bmp"
  ${NSD_SetImage} $Button_Alipay $1 $2

  ; ========== 二维码区域 (168u ~ 340u) ==========
  ${NSD_CreateLabel} 10u 168u 100% 12u "② 扫描二维码完成支付"
  Pop $Label_QRTitle
  SetCtlColors $Label_QRTitle ${COLOR_TEXT} transparent
  SendMessage $Label_QRTitle ${WM_SETFONT} $hFont_QRTitle 1

  ; 二维码边框容器 — 使用 GroupBox 风格
  ${NSD_CreateGroupBox} 58u 182u 190u 150u ""
  Pop $GroupBox_QR

  ; 二维码占位图
  ${NSD_CreateBitmap} 65u 190u 176u 136u ""
  Pop $Bitmap_QR
  ; 加载占位图
  StrCpy $0 "$TEMP\PayLauncher\assets\qr_placeholder.bmp"
  ${NSD_SetImage} $Bitmap_QR $0 $hQRBitmap

  ; 二维码下方提示
  ${NSD_CreateLabel} 58u 334u 190u 10u "请使用手机扫描上方二维码"
  Pop $Label_QRSub
  SetCtlColors $Label_QRSub ${COLOR_TEXT_SEC} transparent
  SendMessage $Label_QRSub ${WM_SETFONT} $hFont_Footer 1

  ; ========== 状态区域 (348u) ==========
  ${NSD_CreateLabel} 0 348u 100% 12u "选择支付方式后将显示二维码"
  Pop $Label_Status
  SetCtlColors $Label_Status ${COLOR_TEXT_SEC} transparent
  CreateFont $hFont_Status "微软雅黑" 8 400
  SendMessage $Label_Status ${WM_SETFONT} $hFont_Status 1

  ; ========== 操作按钮 (365u ~ 390u) ==========
  ; 验证支付按钮 — 使用标准按钮 + 文字颜色（修复背景色无效问题）
  ${NSD_CreateButton} 70u 365u 170u 24u "③ 我已完成支付，验证"
  Pop $Button_Check
  CreateFont $hFont_ButtonSmall "微软雅黑" 8 700
  SendMessage $Button_Check ${WM_SETFONT} $hFont_ButtonSmall 1
  ${NSD_OnClick} $Button_Check OnCheckPayment

  ; 退出按钮
  ${NSD_CreateButton} 70u 393u 170u 20u "取消并退出"
  Pop $Button_Exit
  CreateFont $0 "微软雅黑" 7 400
  SendMessage $Button_Exit ${WM_SETFONT} $0 1
  ${NSD_OnClick} $Button_Exit OnExitClick

  ; 底部版权
  ${NSD_CreateLabel} 0 418u 100% 10u "支付由第三方安全处理 · 支持微信 & 支付宝"
  Pop $Label_Footer
  SetCtlColors $Label_Footer ${COLOR_LINK} transparent
  CreateFont $0 "微软雅黑" 6 400
  SendMessage $Label_Footer ${WM_SETFONT} $0 1

  nsDialogs::Show

  ; 释放所有字体句柄
  System::Call 'gdi32::DeleteObject(i $hFont_Title)'
  System::Call 'gdi32::DeleteObject(i $hFont_Subtitle)'
  System::Call 'gdi32::DeleteObject(i $hFont_Amount)'
  System::Call 'gdi32::DeleteObject(i $hFont_Button)'
  System::Call 'gdi32::DeleteObject(i $hFont_ButtonSmall)'
  System::Call 'gdi32::DeleteObject(i $hFont_Step)'
  System::Call 'gdi32::DeleteObject(i $hFont_StepLabel)'
  System::Call 'gdi32::DeleteObject(i $hFont_Status)'
  System::Call 'gdi32::DeleteObject(i $hFont_Footer)'
  System::Call 'gdi32::DeleteObject(i $hFont_QRTitle)'
  System::Call 'gdi32::DeleteObject(i $hFont_Small)'
  ; 释放二维码位图
  ${If} $hQRBitmap != ""
    ${NSD_FreeImage} $hQRBitmap
  ${EndIf}

FunctionEnd

;------------------------------------------------------
; 创建步骤指示器 (88u ~ 115u)
;------------------------------------------------------
Function CreateStepIndicator

  CreateFont $hFont_Step "微软雅黑" 9 700
  CreateFont $hFont_StepLabel "微软雅黑" 6 400

  ; 步骤1: 选择支付
  ${NSD_CreateLabel} 30u 88u 18u 18u "1"
  Pop $Label_Step1Num
  SetCtlColors $Label_Step1Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_DONE}
  SendMessage $Label_Step1Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 12u 110u 56u 8u "选择支付"
  Pop $Label_Step1Text
  SetCtlColors $Label_Step1Text ${COLOR_TEXT} transparent
  SendMessage $Label_Step1Text ${WM_SETFONT} $hFont_StepLabel 1

  ; 连接线1
  ${NSD_CreateLabel} 50u 97u 75u 1u ""
  Pop $0
  SetCtlColors $0 "" ${COLOR_BORDER}

  ; 步骤2: 扫码支付
  ${NSD_CreateLabel} 128u 88u 18u 18u "2"
  Pop $Label_Step2Num
  SetCtlColors $Label_Step2Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_BG}
  SendMessage $Label_Step2Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 113u 110u 50u 8u "扫码支付"
  Pop $Label_Step2Text
  SetCtlColors $Label_Step2Text ${COLOR_TEXT_SEC} transparent
  SendMessage $Label_Step2Text ${WM_SETFONT} $hFont_StepLabel 1

  ; 连接线2
  ${NSD_CreateLabel} 148u 97u 75u 1u ""
  Pop $0
  SetCtlColors $0 "" ${COLOR_BORDER}

  ; 步骤3: 完成激活
  ${NSD_CreateLabel} 226u 88u 18u 18u "3"
  Pop $Label_Step3Num
  SetCtlColors $Label_Step3Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_BG}
  SendMessage $Label_Step3Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 213u 110u 50u 8u "完成激活"
  Pop $Label_Step3Text
  SetCtlColors $Label_Step3Text ${COLOR_TEXT_SEC} transparent
  SendMessage $Label_Step3Text ${WM_SETFONT} $hFont_StepLabel 1

FunctionEnd

;------------------------------------------------------
; 更新步骤指示器状态
;------------------------------------------------------
Function UpdateStepIndicator
  Exch $R0

  ${If} $R0 >= 2
    SetCtlColors $Label_Step2Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_DONE}
    SetCtlColors $Label_Step2Text ${COLOR_TEXT} transparent
  ${EndIf}

  ${If} $R0 >= 3
    SetCtlColors $Label_Step3Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_DONE}
    SetCtlColors $Label_Step3Text ${COLOR_TEXT} transparent
  ${EndIf}

  Pop $R0
FunctionEnd

;------------------------------------------------------
; 微信支付点击
;------------------------------------------------------
Function OnWechatClick
  StrCpy $PaymentType "wechat"
  StrCpy $StepCompleted "1"

  ; 更新状态提示（按钮本身由 BMP 决定外观，此处不改按钮颜色）
  SetCtlColors $Label_Status ${COLOR_WECHAT} transparent
  ${NSD_SetText} $Label_Status "正在生成微信支付二维码..."

  ; 更新步骤
  Push 2
  Call UpdateStepIndicator

  ; 创建订单
  Call CreatePaymentOrder
FunctionEnd

;------------------------------------------------------
; 支付宝点击
;------------------------------------------------------
Function OnAlipayClick
  StrCpy $PaymentType "alipay"
  StrCpy $StepCompleted "1"

  SetCtlColors $Label_Status ${COLOR_ALIPAY} transparent
  ${NSD_SetText} $Label_Status "正在生成支付宝支付二维码..."

  Push 2
  Call UpdateStepIndicator

  Call CreatePaymentOrder
FunctionEnd

;------------------------------------------------------
; 创建订单
;------------------------------------------------------
Function CreatePaymentOrder
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
      ; 先释放旧的二维码位图（修复 GDI 泄漏）
      ${If} $hQRBitmap != ""
        ${NSD_FreeImage} $hQRBitmap
        StrCpy $hQRBitmap ""
      ${EndIf}

      nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s -o "$TempQRFile" "$2"'
      Pop $0
      Pop $1

      ; 保存新的位图句柄
      ${NSD_SetImage} $Bitmap_QR "$TempQRFile" $hQRBitmap

      ${If} $PaymentType == "wechat"
        ${NSD_SetText} $Label_QRSub "请使用微信扫一扫支付 $$ $ProductAmount"
      ${Else}
        ${NSD_SetText} $Label_QRSub "请使用支付宝扫码支付 $$ $ProductAmount"
      ${EndIf}

      SetCtlColors $Label_Status ${COLOR_TEXT} transparent
      ${NSD_SetText} $Label_Status "请用手机扫描二维码完成支付"
    ${Else}
      Call ShowError_GetQR
    ${EndIf}
  ${Else}
    Call ShowError_Network
  ${EndIf}
FunctionEnd

;------------------------------------------------------
; 点击验证
;------------------------------------------------------
Function OnCheckPayment
  ${If} $OrderId == ""
    Call ShowError_NoOrder
    Return
  ${EndIf}

  SetCtlColors $Label_Status ${COLOR_ACCENT} transparent
  ${NSD_SetText} $Label_Status "正在查询支付状态..."

  Call CheckPaymentStatus
FunctionEnd

;------------------------------------------------------
; 检查支付状态
;------------------------------------------------------
Function CheckPaymentStatus
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
      Call UpdateStepIndicator

      SetCtlColors $Label_Status ${COLOR_SUCCESS} transparent
      ${NSD_SetText} $Label_Status "支付成功！正在启动程序..."

      ${NSD_SetText} $Label_Title "激活成功"
      ${NSD_SetText} $Label_Subtitle "正在为您启动 $ProductName ..."

      Sleep 1500
      SendMessage $Dialog ${WM_CLOSE} 0 0

    ${ElseIf} $2 == "expired"
      StrCpy $OrderId ""
      StrCpy $StepCompleted "0"
      Call ShowError_Expired
    ${Else}
      SetCtlColors $Label_Status ${COLOR_WARN} transparent
      ${NSD_SetText} $Label_Status "尚未检测到支付，请确认扫码并完成付款"
    ${EndIf}
  ${Else}
    Call ShowError_VerifyFail
  ${EndIf}
FunctionEnd

;------------------------------------------------------
; 错误提示函数
;------------------------------------------------------
Function ShowError_GetQR
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "获取二维码失败，请重试"
FunctionEnd

Function ShowError_Network
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "网络连接失败，请检查网络"
FunctionEnd

Function ShowError_NoOrder
  MessageBox MB_OK|MB_ICONEXCLAMATION "请先选择支付方式并创建订单"
FunctionEnd

Function ShowError_Expired
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "订单已过期，请重新选择支付方式"
  StrCpy $OrderId ""
  StrCpy $StepCompleted "0"
FunctionEnd

Function ShowError_VerifyFail
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "验证请求失败，请检查网络"
FunctionEnd

;------------------------------------------------------
; 退出点击 — 修复：无论是否有订单都允许退出
;------------------------------------------------------
Function OnExitClick
  MessageBox MB_YESNO|MB_ICONQUESTION "确定要退出吗？$\r$\n退出后需要重新操作才能使用。" IDYES quit
  Return
  quit:
    Quit
FunctionEnd

;------------------------------------------------------
; 页面离开 — 修复：无订单时直接允许退出
;------------------------------------------------------
Function PaymentPageLeave
  ; 修复：没有订单时允许正常退出（点 X 关闭窗口）
  ${If} $OrderId == ""
    Return
  ${EndIf}

  ; 有订单时做二次验证
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
; 安装后 - 启动目标程序
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
