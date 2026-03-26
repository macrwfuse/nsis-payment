;======================================================
; 付费启动器 NSIS 脚本 — 美化版
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

; 自定义窗口尺寸（窄高型，类似手机支付页面）
; NSIS 默认 497x335，我们用 MUI 来自定义
!define MUI_WELCOMEFINISHPAGE_BITMAP_NOSTRETCH

;------------------------------------------------------
; 颜色定义
;------------------------------------------------------
!define COLOR_BG         "FFFFFF"   ; 背景白
!define COLOR_HEADER     "2B2D42"   ; 深蓝灰头部
!define COLOR_ACCENT     "4361EE"   ; 主色蓝
!define COLOR_WECHAT     "07C160"   ; 微信绿
!define COLOR_ALIPAY     "1677FF"   ; 支付宝蓝
!define COLOR_SUCCESS    "00A854"   ; 成功绿
!define COLOR_ERROR      "F5222D"   ; 错误红
!define COLOR_WARN       "FA8C16"   ; 警告橙
!define COLOR_TEXT        "333333"   ; 主文字
!define COLOR_TEXT_SEC    "888888"   ; 次要文字
!define COLOR_TEXT_LIGHT  "FFFFFF"   ; 浅色文字
!define COLOR_BORDER      "E8E8E8"   ; 边框
!define COLOR_STEP_BG     "F0F0F0"   ; 步骤背景
!define COLOR_STEP_DONE   "4361EE"   ; 完成步骤
!define COLOR_DIVIDER     "EEEEEE"   ; 分隔线

;------------------------------------------------------
; 变量
;------------------------------------------------------
Var Dialog
Var Label_Title
Var Label_Subtitle
Var Label_Amount
Var Label_AmountUnit
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
Var Icon_Header
Var GroupBox_Pay
Var GroupBox_QR
Var PaymentType
Var OrderId
Var PayApiUrl
Var ProductAmount
Var ProductName
Var MaxRetryCount
Var CurrentRetry
Var TempQRFile
Var StepCompleted         ; 0=初始, 1=已选支付, 2=已扫码, 3=已支付
Var hFont_Title
Var hFont_Subtitle
Var hFont_Amount
Var hFont_AmountUnit
Var hFont_Button
Var hFont_ButtonSmall
Var hFont_Step
Var hFont_StepDone
Var hFont_Status
Var hFont_Footer
Var hFont_QRTitle

;------------------------------------------------------
; 页面定义
;------------------------------------------------------
Page custom PaymentPage PaymentPageLeave

;------------------------------------------------------
; 安装区段
;------------------------------------------------------
Section "Main"

  SetOutPath "$TEMP\PayLauncher\assets"
  ; 资源文件（后面会生成）
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

SectionEnd

;------------------------------------------------======
; 支付页面
;------------------------------------------------------
Function PaymentPage

  ; 隐藏默认的 MUI 头部
  !insertmacro MUI_HEADER_TEXT "" ""

  ; ========== 创建对话框 ==========
  nsDialogs::Create /NOUNLOAD 1018
  Pop $Dialog
  ${If} $Dialog == error
    Abort
  ${EndIf}

  ; 设置对话框背景色
  SetCtlColors $Dialog "" ${COLOR_BG}

  ; ========== 顶部横幅区域 (0 ~ 55u) ==========
  ; 深色背景条
  ${NSD_CreateLabel} 0 0 100% 55u ""
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT_LIGHT} ${COLOR_HEADER}

  ; 大标题
  ${NSD_CreateLabel} 12u 8u 80% 18u "软件激活"
  Pop $Label_Title
  SetCtlColors $Label_Title ${COLOR_TEXT_LIGHT} ${COLOR_HEADER}
  CreateFont $hFont_Title "微软雅黑" 16 700
  SendMessage $Label_Title ${WM_SETFONT} $hFont_Title 1

  ; 副标题
  ${NSD_CreateLabel} 12u 30u 80% 14u "完成支付即可使用 $ProductName"
  Pop $Label_Subtitle
  SetCtlColors $Label_Subtitle "B0B0B0" ${COLOR_HEADER}
  CreateFont $hFont_Subtitle "微软雅黑" 9 400
  SendMessage $Label_Subtitle ${WM_SETFONT} $hFont_Subtitle 1

  ; ========== 金额展示区域 (60u ~ 95u) ==========
  ; 金额背景
  ${NSD_CreateLabel} 12u 60u calc(100%-24u) 35u ""
  Pop $0
  SetCtlColors $0 "" "F8F9FF"
  ; 边框效果
  CreateFont $0 "微软雅黑" 8 400

  ; "应付金额" 标签
  ${NSD_CreateLabel} 20u 65u 60u 12u "应付金额"
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT_SEC} "F8F9FF"
  CreateFont $hFont_Footer "微软雅黑" 8 400
  SendMessage $0 ${WM_SETFONT} $hFont_Footer 1

  ; 金额数字
  ${NSD_CreateLabel} 20u 76u 80u 18u "¥$ProductAmount"
  Pop $Label_Amount
  SetCtlColors $Label_Amount ${COLOR_ACCENT} "F8F9FF"
  CreateFont $hFont_Amount "Consolas" 18 700
  SendMessage $Label_Amount ${WM_SETFONT} $hFont_Amount 1

  ; 右侧说明
  ${NSD_CreateLabel} 140u 72u 140u 20u "$ProductName$\n一次性付费，终身使用"
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT_SEC} "F8F9FF"
  CreateFont $hFont_Step "微软雅黑" 8 400
  SendMessage $0 ${WM_SETFONT} $hFont_Step 1

  ; ========== 步骤指示器 (100u ~ 140u) ==========
  Call CreateStepIndicator

  ; ========== 支付方式选择 (148u ~ 200u) ==========
  ; 分组标题
  ${NSD_CreateLabel} 12u 148u 100% 14u "① 选择支付方式"
  Pop $0
  SetCtlColors $0 ${COLOR_TEXT} transparent
  CreateFont $hFont_QRTitle "微软雅黑" 9 700
  SendMessage $0 ${WM_SETFONT} $hFont_QRTitle 1

  ; 微信按钮（模拟大按钮）
  ${NSD_CreateButton} 12u 166u 135u 30u "  微信支付"
  Pop $Button_Wechat
  SetCtlColors $Button_Wechat ${COLOR_TEXT_LIGHT} ${COLOR_WECHAT}
  CreateFont $hFont_Button "微软雅黑" 10 700
  SendMessage $Button_Wechat ${WM_SETFONT} $hFont_Button 1
  ${NSD_OnClick} $Button_Wechat OnWechatClick

  ; 支付宝按钮
  ${NSD_CreateButton} 158u 166u 135u 30u "  支付宝"
  Pop $Button_Alipay
  SetCtlColors $Button_Alipay ${COLOR_TEXT_LIGHT} ${COLOR_ALIPAY}
  SendMessage $Button_Alipay ${WM_SETFONT} $hFont_Button 1
  ${NSD_OnClick} $Button_Alipay OnAlipayClick

  ; ========== 二维码区域 (205u ~ 340u) ==========
  ; 分组标题
  ${NSD_CreateLabel} 12u 205u 100% 14u "② 扫描二维码完成支付"
  Pop $Label_QRTitle
  SetCtlColors $Label_QRTitle ${COLOR_TEXT} transparent
  SendMessage $Label_QRTitle ${WM_SETFONT} $hFont_QRTitle 1

  ; 二维码边框容器
  ${NSD_CreateLabel} 68u 222u 174u 174u ""
  Pop $GroupBox_QR
  SetCtlColors $GroupBox_QR ${COLOR_TEXT} ${COLOR_BG}
  ; 用 border 模拟边框

  ; 二维码占位图
  ${NSD_CreateBitmap} 73u 227u 164u 164u ""
  Pop $Bitmap_QR

  ; 二维码下方提示
  ${NSD_CreateLabel} 68u 400u 174u 12u "请使用手机扫描上方二维码"
  Pop $Label_QRSub
  SetCtlColors $Label_QRSub ${COLOR_TEXT_SEC} transparent
  SendMessage $Label_QRSub ${WM_SETFONT} $hFont_Footer 1

  ; ========== 状态区域 ==========
  ${NSD_CreateLabel} 0 418u 100% 16u "选择支付方式后将显示二维码"
  Pop $Label_Status
  SetCtlColors $Label_Status ${COLOR_TEXT_SEC} transparent
  CreateFont $hFont_Status "微软雅黑" 9 400
  SendMessage $Label_Status ${WM_SETFONT} $hFont_Status 1

  ; ========== 操作按钮 (底部) ==========
  ; 验证支付按钮
  ${NSD_CreateButton} 75u 440u 160u 28u "③ 我已完成支付，验证"
  Pop $Button_Check
  SetCtlColors $Button_Check ${COLOR_TEXT_LIGHT} ${COLOR_ACCENT}
  CreateFont $hFont_ButtonSmall "微软雅黑" 9 700
  SendMessage $Button_Check ${WM_SETFONT} $hFont_ButtonSmall 1
  ${NSD_OnClick} $Button_Check OnCheckPayment

  ; 退出按钮
  ${NSD_CreateButton} 75u 474u 160u 22u "取消并退出"
  Pop $Button_Exit
  SetCtlColors $Button_Exit ${COLOR_TEXT_SEC} ${COLOR_BG}
  CreateFont $0 "微软雅黑" 8 400
  SendMessage $Button_Exit ${WM_SETFONT} $0 1
  ${NSD_OnClick} $Button_Exit OnExitClick

  ; 底部版权
  ${NSD_CreateLabel} 0 500u 100% 10u "支付由第三方安全处理 · 支持微信 & 支付宝"
  Pop $Label_Footer
  SetCtlColors $Label_Footer "BBBBBB" transparent
  CreateFont $0 "微软雅黑" 7 400
  SendMessage $Label_Footer ${WM_SETFONT} $0 1

  nsDialogs::Show

  ; 清理字体
  DeleteFontObject $hFont_Title
  DeleteFontObject $hFont_Subtitle
  DeleteFontObject $hFont_Amount
  DeleteFontObject $hFont_Button
  DeleteFontObject $hFont_ButtonSmall
  DeleteFontObject $hFont_Step
  DeleteFontObject $hFont_Status
  DeleteFontObject $hFont_Footer
  DeleteFontObject $hFont_QRTitle

FunctionEnd

;------------------------------------------------------
; 创建步骤指示器
;------------------------------------------------------
Function CreateStepIndicator

  ; 步骤1: 选择支付
  ${NSD_CreateLabel} 30u 100u 20u 20u "1"
  Pop $Label_Step1Num
  SetCtlColors $Label_Step1Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_DONE}
  CreateFont $hFont_Step "微软雅黑" 10 700
  SendMessage $Label_Step1Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 12u 124u 56u 10u "选择支付"
  Pop $Label_Step1Text
  SetCtlColors $Label_Step1Text ${COLOR_TEXT} transparent
  CreateFont $0 "微软雅黑" 7 400
  SendMessage $Label_Step1Text ${WM_SETFONT} $0 1

  ; 连接线1
  ${NSD_CreateLabel} 52u 109u 76u 1u ""
  Pop $0
  SetCtlColors $0 "" ${COLOR_BORDER}

  ; 步骤2: 扫码支付
  ${NSD_CreateLabel} 130u 100u 20u 20u "2"
  Pop $Label_Step2Num
  SetCtlColors $Label_Step2Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_BG}
  SendMessage $Label_Step2Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 115u 124u 50u 10u "扫码支付"
  Pop $Label_Step2Text
  SetCtlColors $Label_Step2Text ${COLOR_TEXT_SEC} transparent
  SendMessage $Label_Step2Text ${WM_SETFONT} $0 1

  ; 连接线2
  ${NSD_CreateLabel} 152u 109u 76u 1u ""
  Pop $1
  SetCtlColors $1 "" ${COLOR_BORDER}

  ; 步骤3: 完成激活
  ${NSD_CreateLabel} 230u 100u 20u 20u "3"
  Pop $Label_Step3Num
  SetCtlColors $Label_Step3Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_BG}
  SendMessage $Label_Step3Num ${WM_SETFONT} $hFont_Step 1

  ${NSD_CreateLabel} 217u 124u 50u 10u "完成激活"
  Pop $Label_Step3Text
  SetCtlColors $Label_Step3Text ${COLOR_TEXT_SEC} transparent
  SendMessage $Label_Step3Text ${WM_SETFONT} $0 1

FunctionEnd

;------------------------------------------------------
; 更新步骤指示器状态
;------------------------------------------------------
Function UpdateStepIndicator
  ; $R0 = 目标步骤 (1/2/3)
  Exch $R0

  ${If} $R0 >= 2
    SetCtlColors $Label_Step2Num ${COLOR_TEXT_LIGHT} ${COLOR_STEP_DONE}
    SetCtlColors $Label_Step2Text ${COLOR_TEXT} transparent
    ; 更新连接线1颜色
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

  ; 更新按钮状态：微信高亮，支付宝灰
  SetCtlColors $Button_Wechat ${COLOR_TEXT_LIGHT} ${COLOR_WECHAT}
  SetCtlColors $Button_Alipay ${COLOR_TEXT_SEC} ${COLOR_STEP_BG}

  ; 更新状态
  SetCtlColors $Label_Status ${COLOR_WECHAT} transparent
  ${NSD_SetText} $Label_Status "⏳ 正在生成微信支付二维码..."

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

  ; 更新按钮状态
  SetCtlColors $Button_Alipay ${COLOR_TEXT_LIGHT} ${COLOR_ALIPAY}
  SetCtlColors $Button_Wechat ${COLOR_TEXT_SEC} ${COLOR_STEP_BG}

  ; 更新状态
  SetCtlColors $Label_Status ${COLOR_ALIPAY} transparent
  ${NSD_SetText} $Label_Status "⏳ 正在生成支付宝支付二维码..."

  ; 更新步骤
  Push 2
  Call UpdateStepIndicator

  Call CreatePaymentOrder

FunctionEnd

;------------------------------------------------------
; 创建订单
;------------------------------------------------------
Function CreatePaymentOrder
  ; 生成订单号：纯字符串拼接，完全不用 IntOp
  ${GetTime} "" "L" $0 $1 $2 $3 $4 $5 $6
  ; $2=年 $4=月 $5=日 $6=时间
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
      nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s -o "$TempQRFile" "$2"'
      Pop $0
      Pop $1

      ${NSD_SetImage} $Bitmap_QR "$TempQRFile" $0

      ${If} $PaymentType == "wechat"
        ${NSD_SetText} $Label_QRSub "请使用微信扫一扫支付 ¥$ProductAmount"
      ${Else}
        ${NSD_SetText} $Label_QRSub "请使用支付宝扫码支付 ¥$ProductAmount"
      ${EndIf}

      SetCtlColors $Label_Status ${COLOR_TEXT} transparent
      ${NSD_SetText} $Label_Status "📱 请用手机扫描二维码完成支付"
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
  ${NSD_SetText} $Label_Status "🔄 正在查询支付状态..."

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
      ; 支付成功！
      StrCpy $StepCompleted "3"

      ; 更新步骤指示器
      Push 3
      Call UpdateStepIndicator

      ; 成功状态
      SetCtlColors $Label_Status ${COLOR_SUCCESS} transparent
      ${NSD_SetText} $Label_Status "✅ 支付成功！正在启动程序..."

      ; 更新标题
      ${NSD_SetText} $Label_Title "激活成功"
      ${NSD_SetText} $Label_Subtitle "正在为您启动 $ProductName ..."

      Sleep 1500
      ; 关闭对话框，进入下一步
      SendMessage $Dialog ${WM_CLOSE} 0 0

    ${ElseIf} $2 == "expired"
      StrCpy $OrderId ""
      StrCpy $StepCompleted "0"
      Call ShowError_Expired
    ${Else}
      SetCtlColors $Label_Status ${COLOR_WARN} transparent
      ${NSD_SetText} $Label_Status "⏳ 尚未检测到支付，请确认扫码并完成付款"
    ${EndIf}
  ${Else}
    Call ShowError_VerifyFail
  ${EndIf}

FunctionEnd

;------------------------------------------------------
; 错误提示函数（独立命名，避免 Call 传参问题）
;------------------------------------------------------
Function ShowError_GetQR
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "❌ 获取二维码失败，请重试"
FunctionEnd

Function ShowError_Network
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "❌ 网络连接失败，请检查网络"
FunctionEnd

Function ShowError_NoOrder
  MessageBox MB_OK|MB_ICONEXCLAMATION "请先选择支付方式并创建订单"
FunctionEnd

Function ShowError_Expired
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "⏰ 订单已过期，请重新选择支付方式"
  StrCpy $OrderId ""
  StrCpy $StepCompleted "0"
FunctionEnd

Function ShowError_VerifyFail
  SetCtlColors $Label_Status ${COLOR_ERROR} transparent
  ${NSD_SetText} $Label_Status "❌ 验证请求失败，请检查网络"
FunctionEnd

;------------------------------------------------------
; 退出点击
;------------------------------------------------------
Function OnExitClick
  MessageBox MB_YESNO|MB_ICONQUESTION "确定要退出吗？$\n退出后需要重新操作才能使用。" IDYES quit
  Return
  quit:
    Quit
FunctionEnd

;------------------------------------------------------
; 页面离开
;------------------------------------------------------
Function PaymentPageLeave
  ${If} $OrderId == ""
    Abort
  ${EndIf}

  ; 二次验证
  nsExec::ExecToStack '"$TEMP\PayLauncher\curl.exe" -s "$PayApiUrl/check_status?order_id=$OrderId"'
  Pop $0
  Pop $1

  Push "status"
  Push $1
  Call SimpleJsonExtract
  Pop $2

  ${If} $2 != "paid"
    MessageBox MB_OK|MB_ICONEXCLAMATION "支付尚未完成，请先完成支付后再继续。"
    Abort
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
; 辅助函数（与之前相同）
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
