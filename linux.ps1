<#
.SYNOPSIS
    Linux on Windows - Intuitive WSL2 installation & removal manager
.DESCRIPTION
    Support running directly via: irm https://wsl.tino.io.vn/linux.ps1 | iex
    Call 4 separate language files: locales/vn.json, locales/en.json, locales/jp.json, locales/lao.json
    Copyright © 2026 minhduc290613. All rights reserved.
#>

$LocalesBaseUrl = "https://wsl.tino.io.vn/locales" # Change to your locales directory URL
$LangStateFile = Join-Path $env:LOCALAPPDATA "LinuxOnWindows\lang.txt"
$SupportedLangs = @("VN", "EN", "JP", "LAO")
$Translations = @{}

function Get-SavedLanguage {
    if (Test-Path $LangStateFile) {
        $saved = (Get-Content -Path $LangStateFile -Raw -ErrorAction SilentlyContinue)
        if ($saved) {
            $code = $saved.Trim().ToUpper()
            if ($code -in $SupportedLangs) {
                return $code
            }
        }
    }
    return "VN"
}

function Save-Language {
    param([string]$Code)
    $dir = Split-Path -Path $LangStateFile -Parent
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    Set-Content -Path $LangStateFile -Value $Code -Encoding UTF8 -NoNewline
}

function Load-LocaleJson {
    param([string]$Code)
    $lower = $Code.ToLower()
    $map = @{}

    # 1. Read from the locales/ directory next to the .ps1 file if there is one
    if ($PSScriptRoot) {
        $localFile = Join-Path $PSScriptRoot "locales\$lower.json"
        if (Test-Path $localFile) {
            $obj = Get-Content -Path $localFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $obj.PSObject.Properties) {
                $map[$p.Name] = [string]$p.Value
            }
            return $map
        }
    }

    # 2. Download locales for irm ... | iex runs (where $PSScriptRoot is empty).
    # GitHub Raw is the canonical UTF-8 source; decode bytes explicitly because
    # Windows PowerShell 5.1 can misread JSON when a host omits its charset header.
    $localeSources = @(
        "https://raw.githubusercontent.com/minhduc290613/linux-on-windows/main/locales"
    )
    if (-not [string]::IsNullOrWhiteSpace($LocalesBaseUrl)) {
        $localeSources += $LocalesBaseUrl.TrimEnd("/")
    }

    foreach ($baseUrl in ($localeSources | Select-Object -Unique)) {
        try {
            $response = Invoke-WebRequest -Uri "$baseUrl/$lower.json" -UseBasicParsing -TimeoutSec 12 -ErrorAction Stop
            $jsonText = [System.Text.Encoding]::UTF8.GetString($response.RawContentStream.ToArray())
            $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop
            if ($null -ne $obj -and $obj.PSObject.Properties.Count -gt 0) {
                foreach ($property in $obj.PSObject.Properties) {
                    $map[$property.Name] = [string]$property.Value
                }
                if ($map.Count -gt 0) {
                    return $map
                }
            }
        }
        catch {
            # Try the next source. Missing keys use the Vietnamese fallback.
        }
    }

    return $map
}

function Initialize-AllLocales {
    foreach ($code in $SupportedLangs) {
        $Translations[$code] = Load-LocaleJson -Code $code
    }
}

Initialize-AllLocales
$CurrentLang = Get-SavedLanguage

function T {
    param(
        [string]$Key,
        [object[]]$Args = @()
    )
    $dict = $Translations[$CurrentLang]
    $val = $null
    if ($dict -and $dict.ContainsKey($Key)) {
        $val = $dict[$Key]
    }
    elseif ($Translations["VN"] -and $Translations["VN"].ContainsKey($Key)) {
        $val = $Translations["VN"][$Key]
    }
    if ([string]::IsNullOrEmpty($val)) {
        return $Key
    }
    if ($Args.Count -gt 0) {
        # Pass formatting arguments as a real object[] so {0}, {1}, etc.
        # are expanded consistently in Windows PowerShell 5.1 and PowerShell 7.
        return [string]::Format(
            [System.Globalization.CultureInfo]::InvariantCulture,
            [string]$val,
            [object[]]@($Args)
        )
    }
    return [string]$val
}


$ErrorActionPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-IsAdmin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdmin)) {
    Add-Type -AssemblyName System.Windows.Forms
    $ask = [System.Windows.Forms.MessageBox]::Show(
        (T "AskAdminText"),
        (T "AskAdminTitle"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )

    if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
        try {
            if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
                Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
            }
            else {
                # In case of running through irm ... | iex: temporarily save script for smooth privilege upgrading
                $tempScript = Join-Path $env:TEMP "linux-on-windows-elevated.ps1"
                $scriptBody = $MyInvocation.MyCommand.ScriptContents
                if ([string]::IsNullOrWhiteSpace($scriptBody)) {
                    throw "Unable to extract script content from memory."
                }
                Set-Content -Path $tempScript -Value $scriptBody -Encoding UTF8
                Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tempScript`""
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show(
                (T "ElevateErrText" @($_.Exception.Message)),
                (T "ElevateErrTitle"),
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    exit. exit
}


Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Dark Modern color palette
$ColBgMain = [System.Drawing.Color]::FromArgb(19, 20, 24)
$ColBgHeader = [System.Drawing.Color]::FromArgb(26, 28, 35)
$ColBgCard = [System.Drawing.Color]::FromArgb(30, 33, 42)
$ColBgInput = [System.Drawing.Color]::FromArgb(22, 24, 30)
$ColAccentBlue = [System.Drawing.Color]::FromArgb(59, 130, 246)
$ColAccentGreen = [System.Drawing.Color]::FromArgb(16, 185, 129)
$ColAccentRed = [System.Drawing.Color]::FromArgb(239, 68, 68)
$ColAccentAmber = [System.Drawing.Color]::FromArgb(245, 158, 11)
$ColTextPrimary = [System.Drawing.Color]::FromArgb(243, 244, 246)
$ColTextMuted = [System.Drawing.Color]::FromArgb(156, 163, 175)
$ColBorder = [System.Drawing.Color]::FromArgb(55, 65, 81)

$FontTitle = New-Object System.Drawing.Font("Segoe UI", 15, [System.Drawing.FontStyle]::Bold)
$FontSubTitle = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)
$FontSection = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$FontNormal = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
$FontBold = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
$FontMono = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)

# Main form
$form = New-Object System.Windows.Forms.Form
$form.Text = T "WindowTitle"
$form.Size = New-Object System.Drawing.Size(880, 680)
$form.MinimumSize = New-Object System.Drawing.Size(840, 640)
$form.StartPosition = "CenterScreen"
$form.BackColor = $ColBgMain
$form.ForeColor = $ColTextPrimary
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox = $false

# ===========================================================================================
# 3. HEADER + LOGO DRAWING WITH GDI+ + LANGUAGE SELECTOR (VN / EN / JP / LAO)
# ===========================================================================================
$panelHeader = New-Object System.Windows.Forms.Panel
$panelHeader.Location = New-Object System.Drawing.Point(0, 0)
$panelHeader.Size = New-Object System.Drawing.Size(880, 74)
$panelHeader.BackColor = $ColBgHeader
$form.Controls.Add($panelHeader)

$picLogo = New-Object System.Windows.Forms.PictureBox
$picLogo.Location = New-Object System.Drawing.Point(20, 13)
$picLogo.Size = New-Object System.Drawing.Size(48, 48)
$picLogo.BackColor = [System.Drawing.Color]::Transparent
$picLogo.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    # Blue-purple rounded background
    $rect = New-Object System.Drawing.Rectangle(2, 2, 44, 44)
    $brushBg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(37, 99, 235),
        [System.Drawing.Color]::FromArgb(124, 58, 237),
        45
    )
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $r = 10
    $path.AddArc(2, 2, $r, $r, 180, 90)
    $path.AddArc(46 - $r, 2, $r, $r, 270, 90)
    $path.AddArc(46 - $r, 46 - $r, $r, $r, 0, 90)
    $path.AddArc(2, 46 - $r, $r, $r, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brushBg, $path)

    # Windows window icon + Linux prompt ">_"
    $penWhite = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2.2)
    $g.DrawLine($penWhite, 13, 17, 21, 24)
    $g.DrawLine($penWhite, 21, 24, 13, 31)
    $g.DrawLine($penWhite, 24, 31, 35, 31)

    $brushDot = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(52, 211, 153))
    $g.FillEllipse($brushDot, 30, 13, 6, 6)
})
$panelHeader.Controls.Add($picLogo)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Linux on Windows"
$lblTitle.Font = $FontTitle
$lblTitle.ForeColor = $ColTextPrimary
$lblTitle.Location = New-Object System.Drawing.Point(80, 12)
$lblTitle.AutoSize = $true
$panelHeader.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = T "SubTitle"
$lblSub.Font = $FontSubTitle
$lblSub.ForeColor = $ColTextMuted
$lblSub.Location = New-Object System.Drawing.Point(82, 42)
$lblSub.AutoSize = $true
$panelHeader.Controls.Add($lblSub)

$lblLang = New-Object System.Windows.Forms.Label
$lblLang.Text = T "LangLabel"
$lblLang.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
$lblLang.ForeColor = $ColTextMuted
$lblLang.Location = New-Object System.Drawing.Point(548, 12)
$lblLang.AutoSize = $true
$panelHeader.Controls.Add($lblLang)

$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.Location = New-Object System.Drawing.Point(605, 8)
$cmbLang.Size = New-Object System.Drawing.Size(76, 24)
$cmbLang.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Bold)
$cmbLang.BackColor = $ColBgInput
$cmbLang.ForeColor = $ColTextPrimary
$cmbLang.DropDownStyle = "DropDownList"
$cmbLang.Items.AddRange($SupportedLangs)
$cmbLang.SelectedItem = $CurrentLang
$panelHeader.Controls.Add($cmbLang)

$lblAdminBadge = New-Object System.Windows.Forms.Label
$lblAdminBadge.Text = T "AdminBadge"
$lblAdminBadge.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblAdminBadge.ForeColor = [System.Drawing.Color]::FromArgb(167, 243, 208)
$lblAdminBadge.BackColor = [System.Drawing.Color]::FromArgb(6, 78, 59)
$lblAdminBadge.Location = New-Object System.Drawing.Point(742, 25)
$lblAdminBadge.Size = New-Object System.Drawing.Size(102, 24)
$lblAdminBadge.TextAlign = "MiddleCenter"
$panelHeader.Controls.Add($lblAdminBadge)

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(20, 86)
$tabControl.Size = New-Object System.Drawing.Size(825, 355)
$tabControl.Font = $FontBold
$form.Controls.Add($tabControl)

$tabInstall = New-Object System.Windows.Forms.TabPage
$tabInstall.Text = T "TabInstall"
$tabInstall.BackColor = $ColBgCard
$tabInstall.ForeColor = $ColTextPrimary
$tabControl.Controls.Add($tabInstall)

$tabRemove = New-Object System.Windows.Forms.TabPage
$tabRemove.Text = T "TabRemove"
$tabRemove.BackColor = $ColBgCard
$tabRemove.ForeColor = $ColTextPrimary
$tabControl.Controls.Add($tabRemove)


$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 452)
$txtLog.Size = New-Object System.Drawing.Size(825, 142)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$txtLog.BackColor = $ColBgInput
$txtLog.ForeColor = [System.Drawing.Color]::FromArgb(209, 213, 219)
$txtLog.Font = $FontMono
$txtLog.BorderStyle = "FixedSingle"
$form.Controls.Add($txtLog)

function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $ts = (Get-Date).ToString("HH:mm:ss")
    $txtLog.AppendText("[$ts] [$Level] $Message`r`n")
    $txtLog.SelectionStart = $txtLog.Text.Length
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Invoke-StepCommand {
    param(
        [string]$Title,
        [scriptblock]$Action
    )
    Write-Log ">>> Start: $Title" "STEP"
    try {
        & $Action
        Write-Log "Done: $Title" "OK"
    }
    catch {
        Write-Log "Error at '$Title': $($_.Exception.Message)" "ERROR"
    }
}

$grpAutoInstall = New-Object System.Windows.Forms.GroupBox
$grpAutoInstall.Text = T "GrpAutoInstall"
$grpAutoInstall.ForeColor = $ColAccentBlue
$grpAutoInstall.Font = $FontSection
$grpAutoInstall.Location = New-Object System.Drawing.Point(15, 12)
$grpAutoInstall.Size = New-Object System.Drawing.Size(375, 298)
$tabInstall.Controls.Add($grpAutoInstall)

$lblDistro = New-Object System.Windows.Forms.Label
$lblDistro.Text = T "LblDistro"
$lblDistro.Font = $FontNormal
$lblDistro.ForeColor = $ColTextPrimary
$lblDistro.Location = New-Object System.Drawing.Point(15, 32)
$lblDistro.AutoSize = $true
$grpAutoInstall.Controls.Add($lblDistro)

$cmbDistro = New-Object System.Windows.Forms.ComboBox
$cmbDistro.Location = New-Object System.Drawing.Point(15, 56)
$cmbDistro.Size = New-Object System.Drawing.Size(255, 28)
$cmbDistro.Font = $FontNormal
$cmbDistro.BackColor = $ColBgInput
$cmbDistro.ForeColor = $ColTextPrimary
$cmbDistro.DropDownStyle = "DropDown"
$cmbDistro.Items.AddRange(@(
    "Ubuntu",
    "Ubuntu-24.04",
    "Ubuntu-22.04",
    "Debian",
    "kali-linux",
    "openSUSE-Tumbleweed",
    "OracleLinux_9_1"
))
$cmbDistro.SelectedIndex = 0
$grpAutoInstall.Controls.Add($cmbDistro)

$btnRefreshDistro = New-Object System.Windows.Forms.Button
$btnRefreshDistro.Text = T "BtnRefreshDistro"
$btnRefreshDistro.Font = $FontNormal
$btnRefreshDistro.Location = New-Object System.Drawing.Point(278, 55)
$btnRefreshDistro.Size = New-Object System.Drawing.Size(82, 27)
$btnRefreshDistro.BackColor = $ColBgHeader
$btnRefreshDistro.ForeColor = $ColTextPrimary
$btnRefreshDistro.FlatStyle = "Flat"
$grpAutoInstall.Controls.Add($btnRefreshDistro)

$lblGuideAuto = New-Object System.Windows.Forms.Label
$lblGuideAuto.Text = T "LblGuideAuto"
$lblGuideAuto.Font = $FontSubTitle
$lblGuideAuto.ForeColor = $ColTextMuted
$lblGuideAuto.Location = New-Object System.Drawing.Point(15, 98)
$lblGuideAuto.Size = New-Object System.Drawing.Size(345, 95)
$grpAutoInstall.Controls.Add($lblGuideAuto)

$btnInstallAuto = New-Object System.Windows.Forms.Button
$btnInstallAuto.Text = T "BtnInstallAuto"
$btnInstallAuto.Font = $FontBold
$btnInstallAuto.Location = New-Object System.Drawing.Point(15, 202)
$btnInstallAuto.Size = New-Object System.Drawing.Size(345, 38)
$btnInstallAuto.BackColor = $ColAccentGreen
$btnInstallAuto.ForeColor = [System.Drawing.Color]::White
$btnInstallAuto.FlatStyle = "Flat"
$grpAutoInstall.Controls.Add($btnInstallAuto)

$btnCheckStatus = New-Object System.Windows.Forms.Button
$btnCheckStatus.Text = T "BtnCheckStatus"
$btnCheckStatus.Font = $FontNormal
$btnCheckStatus.Location = New-Object System.Drawing.Point(15, 248)
$btnCheckStatus.Size = New-Object System.Drawing.Size(345, 32)
$btnCheckStatus.BackColor = $ColBgHeader
$btnCheckStatus.ForeColor = $ColTextPrimary
$btnCheckStatus.FlatStyle = "Flat"
$grpAutoInstall.Controls.Add($btnCheckStatus)

# --- Right column: Install Custom step by step with instructions ---
$grpCustomInstall = New-Object System.Windows.Forms.GroupBox
$grpCustomInstall.Text = T "GrpCustomInstall"
$grpCustomInstall.ForeColor = $ColAccentAmber
$grpCustomInstall.Font = $FontSection
$grpCustomInstall.Location = New-Object System.Drawing.Point(405, 12)
$grpCustomInstall.Size = New-Object System.Drawing.Size(400, 298)
$tabInstall.Controls.Add($grpCustomInstall)

$stepButtons = @(
    @{
        Y = 28; TitleKey = "Step1Title"; HintKey = "Step1Hint";
        Cmd = {
            $out = dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1
            $out | ForEach-Object { Write-Log $_ "DISM" }
        }
    },
    @{
        Y = 82; TitleKey = "Step2Title"; HintKey = "Step2Hint";
        Cmd = {
            $out = dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1
            $out | ForEach-Object { Write-Log $_ "DISM" }
        }
    },
    @{
        Y = 136; TitleKey = "Step3Title"; HintKey = "Step3Hint";
        Cmd = {
            wsl --update 2>&1 | ForEach-Object { Write-Log $_ "WSL" }
            wsl --set-default-version 2 2>&1 | ForEach-Object { Write-Log $_ "WSL" }
        }
    },
    @{
        Y = 190; TitleKey = "Step4Title"; HintKey = "Step4Hint";
        Cmd = {
            $d = $cmbDistro.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($d)) { throw "Please select or enter a Distro name." }
            Write-Log "Installing distro: $d ..." "WSL"
            wsl --install -d $d 2>&1 | ForEach-Object { Write-Log $_ "WSL" }
        }
    }
)

$stepHintLabels = @()
foreach ($sb in $stepButtons) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = T $sb.TitleKey
    $btn.Font = $FontBold
    $btn.Location = New-Object System.Drawing.Point(15, $sb.Y)
    $btn.Size = New-Object System.Drawing.Size(370, 28)
    $btn.BackColor = $ColBgHeader
    $btn.ForeColor = $ColTextPrimary
    $btn.FlatStyle = "Flat"
    $btn.TextAlign = "MiddleLeft"
    $btn.Tag = $sb
    $btn.Add_Click({
        param($sender, $e)
        $info = $sender.Tag
        Invoke-StepCommand -Title (T $info.TitleKey) -Action $info.Cmd
    })
    $grpCustomInstall.Controls.Add($btn)

    $lblHint = New-Object System.Windows.Forms.Label
    $lblHint.Text = T $sb.HintKey
    $lblHint.Font = New-Object System.Drawing.Font("Segoe UI", 8.2)
    $lblHint.ForeColor = $ColTextMuted
    $lblHint.Location = New-Object System.Drawing.Point(18, ($sb.Y + 30))
    $lblHint.AutoSize = $true
    $grpCustomInstall.Controls.Add($lblHint)
    $stepHintLabels += @{ Label = $lblHint; HintKey = $sb.HintKey }
}

$lblBiosNote = New-Object System.Windows.Forms.Label
$lblBiosNote.Text = T "LblBiosNote"
$lblBiosNote.Font = New-Object System.Drawing.Font("Segoe UI", 8.2, [System.Drawing.FontStyle]::Italic)
$lblBiosNote.ForeColor = $ColAccentAmber
$lblBiosNote.Location = New-Object System.Drawing.Point(15, 255)
$lblBiosNote.Size = New-Object System.Drawing.Size(370, 32)
$grpCustomInstall.Controls.Add($lblBiosNote)

$grpRemoveAuto = New-Object System.Windows.Forms.GroupBox
$grpRemoveAuto.Text = T "GrpRemoveAuto"
$grpRemoveAuto.ForeColor = $ColAccentRed
$grpRemoveAuto.Font = $FontSection
$grpRemoveAuto.Location = New-Object System.Drawing.Point(15, 12)
$grpRemoveAuto.Size = New-Object System.Drawing.Size(345, 298)
$tabRemove.Controls.Add($grpRemoveAuto)

$lblWarnRemove = New-Object System.Windows.Forms.Label
$lblWarnRemove.Text = T "LblWarnRemove"
$lblWarnRemove.Font = $FontSubTitle
$lblWarnRemove.ForeColor = [System.Drawing.Color]::FromArgb(252, 165, 165)
$lblWarnRemove.Location = New-Object System.Drawing.Point(15, 30)
$lblWarnRemove.Size = New-Object System.Drawing.Size(315, 110)
$grpRemoveAuto.Controls.Add($lblWarnRemove)

$btnRemoveAuto = New-Object System.Windows.Forms.Button
$btnRemoveAuto.Text = T "BtnRemoveAuto"
$btnRemoveAuto.Font = $FontBold
$btnRemoveAuto.Location = New-Object System.Drawing.Point(15, 152)
$btnRemoveAuto.Size = New-Object System.Drawing.Size(315, 42)
$btnRemoveAuto.BackColor = $ColAccentRed
$btnRemoveAuto.ForeColor = [System.Drawing.Color]::White
$btnRemoveAuto.FlatStyle = "Flat"
$grpRemoveAuto.Controls.Add($btnRemoveAuto)

$btnRestartExplorer = New-Object System.Windows.Forms.Button
$btnRestartExplorer.Text = T "BtnRestartExplorer"
$btnRestartExplorer.Font = $FontNormal
$btnRestartExplorer.Location = New-Object System.Drawing.Point(15, 206)
$btnRestartExplorer.Size = New-Object System.Drawing.Size(315, 34)
$btnRestartExplorer.BackColor = $ColBgHeader
$btnRestartExplorer.ForeColor = $ColTextPrimary
$btnRestartExplorer.FlatStyle = "Flat"
$grpRemoveAuto.Controls.Add($btnRestartExplorer)

$btnRestartPC = New-Object System.Windows.Forms.Button
$btnRestartPC.Text = T "BtnRestartPC"
$btnRestartPC.Font = $FontNormal
$btnRestartPC.Location = New-Object System.Drawing.Point(15, 248)
$btnRestartPC.Size = New-Object System.Drawing.Size(315, 32)
$btnRestartPC.BackColor = $ColBgHeader
$btnRestartPC.ForeColor = $ColAccentAmber
$btnRestartPC.FlatStyle = "Flat"
$grpRemoveAuto.Controls.Add($btnRestartPC)

$grpRemoveCustom = New-Object System.Windows.Forms.GroupBox
$grpRemoveCustom.Text = T "GrpRemoveCustom"
$grpRemoveCustom.ForeColor = $ColAccentBlue
$grpRemoveCustom.Font = $FontSection
$grpRemoveCustom.Location = New-Object System.Drawing.Point(375, 12)
$grpRemoveCustom.Size = New-Object System.Drawing.Size(430, 298)
$tabRemove.Controls.Add($grpRemoveCustom)

$chkUnregisterAll = New-Object System.Windows.Forms.CheckBox
$chkUnregisterAll.Text = T "ChkUnregisterAll"
$chkUnregisterAll.Font = $FontNormal
$chkUnregisterAll.Checked = $true
$chkUnregisterAll.Location = New-Object System.Drawing.Point(15, 28)
$chkUnregisterAll.Size = New-Object System.Drawing.Size(400, 24)
$grpRemoveCustom.Controls.Add($chkUnregisterAll)

$chkDisableFeatures = New-Object System.Windows.Forms.CheckBox
$chkDisableFeatures.Text = T "ChkDisableFeatures"
$chkDisableFeatures.Font = $FontNormal
$chkDisableFeatures.Checked = $true
$chkDisableFeatures.Location = New-Object System.Drawing.Point(15, 58)
$chkDisableFeatures.Size = New-Object System.Drawing.Size(400, 24)
$grpRemoveCustom.Controls.Add($chkDisableFeatures)

$chkRemoveAppxMsi = New-Object System.Windows.Forms.CheckBox
$chkRemoveAppxMsi.Text = T "ChkRemoveAppxMsi"
$chkRemoveAppxMsi.Font = $FontNormal
$chkRemoveAppxMsi.Checked = $true
$chkRemoveAppxMsi.Location = New-Object System.Drawing.Point(15, 88)
$chkRemoveAppxMsi.Size = New-Object System.Drawing.Size(400, 24)
$grpRemoveCustom.Controls.Add($chkRemoveAppxMsi)

$chkKillAndDeleteDir = New-Object System.Windows.Forms.CheckBox
$chkKillAndDeleteDir.Text = T "ChkKillAndDeleteDir"
$chkKillAndDeleteDir.Font = $FontNormal
$chkKillAndDeleteDir.Checked = $true
$chkKillAndDeleteDir.Location = New-Object System.Drawing.Point(15, 118)
$chkKillAndDeleteDir.Size = New-Object System.Drawing.Size(400, 24)
$grpRemoveCustom.Controls.Add($chkKillAndDeleteDir)

$chkCleanRegistryIcon = New-Object System.Windows.Forms.CheckBox
$chkCleanRegistryIcon.Text = T "ChkCleanRegistryIcon"
$chkCleanRegistryIcon.Font = $FontNormal
$chkCleanRegistryIcon.Checked = $true
$chkCleanRegistryIcon.Location = New-Object System.Drawing.Point(15, 148)
$chkCleanRegistryIcon.Size = New-Object System.Drawing.Size(400, 24)
$grpRemoveCustom.Controls.Add($chkCleanRegistryIcon)

$chkCleanUserCache = New-Object System.Windows.Forms.CheckBox
$chkCleanUserCache.Text = T "ChkCleanUserCache"
$chkCleanUserCache.Font = $FontNormal
$chkCleanUserCache.Checked = $false
$chkCleanUserCache.Location = New-Object System.Drawing.Point(15, 178)
$chkCleanUserCache.Size = New-Object System.Drawing.Size(400, 24)
$grpRemoveCustom.Controls.Add($chkCleanUserCache)

$btnRemoveCustom = New-Object System.Windows.Forms.Button
$btnRemoveCustom.Text = T "BtnRemoveCustom"
$btnRemoveCustom.Font = $FontBold
$btnRemoveCustom.Location = New-Object System.Drawing.Point(15, 218)
$btnRemoveCustom.Size = New-Object System.Drawing.Size(400, 38)
$btnRemoveCustom.BackColor = $ColAccentBlue
$btnRemoveCustom.ForeColor = [System.Drawing.Color]::White
$btnRemoveCustom.FlatStyle = "Flat"
$grpRemoveCustom.Controls.Add($btnRemoveCustom)

$lblCustomHint = New-Object System.Windows.Forms.Label
$lblCustomHint.Text = T "LblCustomHint"
$lblCustomHint.Font = New-Object System.Drawing.Font("Segoe UI", 8.2)
$lblCustomHint.ForeColor = $ColTextMuted
$lblCustomHint.Location = New-Object System.Drawing.Point(15, 264)
$lblCustomHint.Size = New-Object System.Drawing.Size(400, 26)
$grpRemoveCustom.Controls.Add($lblCustomHint)


function Apply-Language {
    param([string]$Code)
    if (-not $Translations.ContainsKey($Code)) { return }
    $script:CurrentLang = $Code
    Save-Language -Code $Code

    $form.Text = T "WindowTitle"
    $lblSub.Text = T "SubTitle"
    $lblLang.Text = T "LangLabel"
    $lblAdminBadge.Text = T "AdminBadge"

    $tabInstall.Text = T "TabInstall"
    $tabRemove.Text = T "TabRemove"

    $grpAutoInstall.Text = T "GrpAutoInstall"
    $lblDistro.Text = T "LblDistro"
    $btnRefreshDistro.Text = T "BtnRefreshDistro"
    $lblGuideAuto.Text = T "LblGuideAuto"
    $btnInstallAuto.Text = T "BtnInstallAuto"
    $btnCheckStatus.Text = T "BtnCheckStatus"

    $grpCustomInstall.Text = T "GrpCustomInstall"
    foreach ($ctrl in $grpCustomInstall.Controls) {
        if ($ctrl -is [System.Windows.Forms.Button] -and $ctrl.Tag) {
            $ctrl.Text = T $ctrl.Tag.TitleKey
        }
    }
    foreach ($item in $stepHintLabels) {
        $item.Label.Text = T $item.HintKey
    }
    $lblBiosNote.Text = T "LblBiosNote"

    $grpRemoveAuto.Text = T "GrpRemoveAuto"
    $lblWarnRemove.Text = T "LblWarnRemove"
    $btnRemoveAuto.Text = T "BtnRemoveAuto"
    $btnRestartExplorer.Text = T "BtnRestartExplorer"
    $btnRestartPC.Text = T "BtnRestartPC"

    $grpRemoveCustom.Text = T "GrpRemoveCustom"
    $chkUnregisterAll.Text = T "ChkUnregisterAll"
    $chkDisableFeatures.Text = T "ChkDisableFeatures"
    $chkRemoveAppxMsi.Text = T "ChkRemoveAppxMsi"
    $chkKillAndDeleteDir.Text = T "ChkKillAndDeleteDir"
    $chkCleanRegistryIcon.Text = T "ChkCleanRegistryIcon"
    $chkCleanUserCache.Text = T "ChkCleanUserCache"
    $btnRemoveCustom.Text = T "BtnRemoveCustom"
    $lblCustomHint.Text = T "LblCustomHint"

    $lblCredit.Text = T "CreditText"
}

$cmbLang.Add_SelectedIndexChanged({
    $selected = [string]$cmbLang.SelectedItem
    if (-not [string]::IsNullOrWhiteSpace($selected) -and $selected -ne $CurrentLang) {
        Apply-Language -Code $selected
        Write-Log (T "LangChangedLog" @($selected)) "LANG"
    }
})

function Invoke-UnregisterAllDistros {
    Invoke-StepCommand -Title "Stop WSL & deregister entire Distro" -Action {
        wsl --shutdown 2>$null
        $rawList = wsl -l -q 2>$null
        if ($rawList) {
            foreach ($line in $rawList) {
                $name = ($line -replace "`0", "").Trim()
                if (-not [string]::IsNullOrWhiteSpace($name)) {
                    Write-Log "Unregistering distro: $name" "WSL"
                    wsl --unregister $name 2>&1 | ForEach-Object { Write-Log $_ "WSL" }
                }
            }
        }
        else {
            Write-Log "No registered distros found." "INFO"
        }
    }
}

function Invoke-DisableWslFeatures {
    Invoke-StepCommand -Title "Disable Windows Subsystem for Linux & Virtual Machine Platform" -Action {
        dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart 2>&1 | ForEach-Object { Write-Log $_ "DISM" }
        dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart 2>&1 | ForEach-Object { Write-Log $_ "DISM" }
    }
}

function Invoke-RemoveAppxAndMsi {
    Invoke-StepCommand -Title "Uninstall Appx, Provisioned & MSI Packages (WSL/Ubuntu)" -Action {
        Get-AppxPackage -AllUsers *WSL* -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "Uninstall Appx: $($_.Name)" "APPX"
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
        Get-AppxPackage -AllUsers *CanonicalGroupLimited* -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "Uninstall Appx Ubuntu: $($_.Name)" "APPX"
            Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        }
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*WSL*" -or $_.DisplayName -like "*CanonicalGroupLimited*"
        } | ForEach-Object {
            Write-Log "Remove Provisioned: $($_.DisplayName)" "APPX"
            Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction SilentlyContinue | Out-Null
        }

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            winget uninstall "Windows Subsystem for Linux" --silent --accept-source-agreements 2>$null | Out-Null
        }

        $uninstallPaths = @(
            "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*Windows Subsystem for Linux*"
        } | ForEach-Object {
            Write-Log "Uninstall MSI package: $($_.DisplayName) ($($_.PSChildName))" "MSI"
            Start-Process msiexec.exe -ArgumentList "/x $($_.PSChildName) /qn /norestart" -Wait -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-KillAndDeleteProgramFiles {
    Invoke-StepCommand -Title "Stop background process & delete C:\Program Files\WSL" -Action {
        Stop-Service WSLService -Force -ErrorAction SilentlyContinue
        foreach ($proc in @("wslservice.exe", "wsl.exe", "wslhost.exe", "wslsettings.exe")) {
            taskkill /F /IM $proc /T 2>$null | Out-Null
        }
        Start-Sleep -Milliseconds 500
        if (Test-Path "C:\Program Files\WSL") {
            Remove-Item -Path "C:\Program Files\WSL" -Recurse -Force -ErrorAction Stop
            Write-Log "C:\Program Files\WSL folder has been wiped clean." "OK"
        }
        else {
            Write-Log "Directory C:\Program Files\WSL does not exist." "INFO"
        }
    }
}

function Invoke-CleanExplorerAndShortcuts {
    Invoke-StepCommand -Title "Remove Linux icon (CLSID) from Explorer & clean Start Menu shortcut" -Action {
        $regKeys = @(
            "HKCU:\Software\Classes\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}",
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}"
        )
        foreach ($rk in $regKeys) {
            if (Test-Path $rk) {
                Remove-Item -Path $rk -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Registry key deleted: $rk" "REG"
            }
        }

        $startDirs = @(
            "$env:AppData\Microsoft\Windows\Start Menu\Programs",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        )
        foreach ($dir in $startDirs) {
            if (Test-Path $dir) {
                Get-ChildItem -Path $dir -Filter "*WSL*.lnk" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
                Get-ChildItem -Path $dir -Filter "*Ubuntu*.lnk" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Invoke-CleanUserCache {
    Invoke-StepCommand -Title "Clean up .wslconfig configuration files & Ubuntu AppData cache" -Action {
        $wslCfg = Join-Path $env:USERPROFILE ".wslconfig"
        if (Test-Path $wslCfg) {
            Remove-Item $wslCfg -Force -ErrorAction SilentlyContinue
            Write-Log "$wslCfg deleted" "CLEAN"
        }
        $pkgDir = Join-Path $env:LOCALAPPDATA "Packages"
        if (Test-Path $pkgDir) {
            Get-ChildItem -Path $pkgDir -Filter "CanonicalGroupLimited*" -ErrorAction SilentlyContinue | ForEach-Object {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Cache folder deleted: $($_.Name)" "CLEAN"
            }
        }
    }
}

function Invoke-RefreshShell {
    Invoke-StepCommand -Title "Refresh SearchHost and File Explorer" -Action {
        Stop-Process -Name SearchHost -Force -ErrorAction SilentlyContinue
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    }
}

$btnRefreshDistro.Add_Click({
    Invoke-StepCommand -Title "Get Online Distro List" -Action {
        $lines = wsl --list --online 2>&1
        $parsed = @()
        foreach ($l in $lines) {
            $clean = ($l -replace "`0", "").Trim()
            if ($clean -match "^([A-Za-z0-9._-]+)\s{2,}") {
                $name = $Matches[1]
                if ($name -notin @("NAME", "The")) {
                    $parsed += $name
                }
            }
        }
        if ($parsed.Count -gt 0) {
            $cmbDistro.Items.Clear()
            $cmbDistro.Items.AddRange($parsed)
            $cmbDistro.SelectedIndex = 0
            Write-Log "$($parsed.Count) distro online updated." "OK"
        }
        else {
            Write-Log "Failed to get online list (test network or WSL CLI)." "WARN"
        }
    }
})

$btnCheckStatus.Add_Click({
    Invoke-StepCommand -Title "Check current WSL status" -Action {
        wsl --status 2>&1 | ForEach-Object { Write-Log ($_ -replace "`0", "") "STATUS" }
        wsl -l -v 2>&1 | ForEach-Object { Write-Log ($_ -replace "`0", "") "DISTRO" }
    }
})

$btnInstallAuto.Add_Click({
    $distro = $cmbDistro.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($distro)) {
        [System.Windows.Forms.MessageBox]::Show((T "MissingDistroText"), (T "MissingDistroTitle"))
        return
    }

    $confirm = [System.Windows.Forms.MessageBox]::Show(
        (T "ConfirmInstallText" @($distro)),
        (T "ConfirmInstallTitle"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Invoke-StepCommand -Title "INSTALL AUTO WSL2 + $distro" -Action {
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1 | ForEach-Object { Write-Log $_ "DISM" }
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1 | ForEach-Object { Write-Log $_ "DISM" }
        wsl --update 2>&1 | ForEach-Object { Write-Log $_ "WSL" }
        wsl --set-default-version 2 2>&1 | ForEach-Object { Write-Log $_ "WSL" }
        wsl --install -d $distro 2>&1 | ForEach-Object { Write-Log $_ "WSL" }
    }
    [System.Windows.Forms.MessageBox]::Show(
        (T "InstallDoneText"),
        "Linux on Windows",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

$btnRemoveAuto.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        (T "ConfirmRemAutoText"),
        (T "ConfirmRemAutoTitle"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    Invoke-UnregisterAllDistros
    Invoke-DisableWslFeatures
    Invoke-RemoveAppxAndMsi
    Invoke-KillAndDeleteProgramFiles
    Invoke-CleanExplorerAndShortcuts
    Invoke-CleanUserCache
    Invoke-RefreshShell

    [System.Windows.Forms.MessageBox]::Show(
        (T "RemAutoDoneText"),
        "Linux on Windows",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
})

$btnRemoveCustom.Add_Click({
    $confirm = [System.Windows.Forms.MessageBox]::Show(
        (T "ConfirmRemCustText"),
        (T "ConfirmRemCustTitle"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    if ($chkUnregisterAll.Checked) { Invoke-UnregisterAllDistros }
    if ($chkDisableFeatures.Checked) { Invoke-DisableWslFeatures }
    if ($chkRemoveAppxMsi.Checked) { Invoke-RemoveAppxAndMsi }
    if ($chkKillAndDeleteDir.Checked) { Invoke-KillAndDeleteProgramFiles }
    if ($chkCleanRegistryIcon.Checked) {
        Invoke-CleanExplorerAndShortcuts
        Invoke-RefreshShell
    }
    if ($chkCleanUserCache.Checked) { Invoke-CleanUserCache }

    Write-Log "Hoàn tất quy trình Xóa Custom." "OK"
})

$btnRestartExplorer.Add_Click({
    Invoke-RefreshShell
})

$btnRestartPC.Add_Click({
    $ask = [System.Windows.Forms.MessageBox]::Show(
        (T "ConfirmRestartText"),
        (T "ConfirmRestartTitle"),
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) {
        Restart-Computer -Force
    }
})


$panelFooter = New-Object System.Windows.Forms.Panel
$panelFooter.Location = New-Object System.Drawing.Point(20, 602)
$panelFooter.Size = New-Object System.Drawing.Size(825, 30)
$form.Controls.Add($panelFooter)

$lblCredit = New-Object System.Windows.Forms.Label
$lblCredit.Text = T "CreditText"
$lblCredit.Font = $FontNormal
$lblCredit.ForeColor = $ColTextMuted
$lblCredit.Location = New-Object System.Drawing.Point(0, 5)
$lblCredit.AutoSize = $true
$panelFooter.Controls.Add($lblCredit)

$lnkGithub = New-Object System.Windows.Forms.LinkLabel
$lnkGithub.Text = "GitHub: https://github.com/minhduc290613"
$lnkGithub.Font = $FontNormal
$lnkGithub.LinkColor = [System.Drawing.Color]::FromArgb(96, 165, 250)
$lnkGithub.ActiveLinkColor = [System.Drawing.Color]::FromArgb(147, 197, 253)
$lnkGithub.VisitedLinkColor = [System.Drawing.Color]::FromArgb(96, 165, 250)
$lnkGithub.Location = New-Object System.Drawing.Point(565, 5)
$lnkGithub.AutoSize = $true
$lnkGithub.Add_LinkClicked({
    Start-Process "https://github.com/minhduc290613"
})
$panelFooter.Controls.Add($lnkGithub)

# Run
Write-Log (T "ReadyLog") "READY"
[void]$form.ShowDialog()