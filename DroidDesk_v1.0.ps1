# DroidDesk v1.0 — polished Android desktop workspace
# Windows 10 + scrcpy + adb.exe. PowerShell WinForms, no heavy framework.
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName Microsoft.VisualBasic
[Windows.Forms.Application]::EnableVisualStyles()

$script:ScrcpyPath = ""
$script:AdbPath = ""
$script:AdbSerial = ""
$script:ConnectionMode = "USB"
$script:Packages = @()
$script:LastAdbExitCode = 0
$script:Favorites = @()
$script:RecentApps = @()
$script:UserDataDir = Join-Path $env:APPDATA "DroidDesk"
$script:UserDataFile = Join-Path $script:UserDataDir "user-data.json"
$script:AaptPath = ""
$script:AppNameCacheFile = Join-Path $script:UserDataDir "app-names.json"
$script:AppNameCache = @{}

try {
 if(Test-Path $script:AppNameCacheFile) {
  $savedNames = Get-Content $script:AppNameCacheFile -Raw | ConvertFrom-Json
  foreach($prop in $savedNames.PSObject.Properties) {
   if($prop.Value) {
    $script:AppNameCache[$prop.Name] = [string]$prop.Value
   }
  }
 }
} catch {}
$script:CategoryFilter = "All"
$script:FavoritesOnly = $false
$script:RecentOnly = $false
try {
 if(Test-Path $script:UserDataFile){
  $saved=Get-Content $script:UserDataFile -Raw | ConvertFrom-Json
  if($saved.Favorites){$script:Favorites=@($saved.Favorites)}
  if($saved.RecentApps){$script:RecentApps=@($saved.RecentApps)}
 }
} catch {}
$script:KnownApps = @{
 "com.google.android.apps.bard"="Gemini"
 "com.google.android.apps.googleassistant"="Google Assistant"
 "com.google.android.apps.youtube.music"="YouTube Music"
 "com.google.android.youtube"="YouTube"
 "com.whatsapp"="WhatsApp"
 "com.facebook.orca"="Messenger"
 "com.facebook.katana"="Facebook"
 "com.android.chrome"="Chrome"
 "com.instagram.android"="Instagram"
 "com.spotify.music"="Spotify"
 "com.google.android.gm"="Gmail"
 "com.google.android.apps.maps"="Google Maps"
 "com.google.android.apps.photos"="Google Photos"
 "com.android.settings"="Settings"
 "com.android.vending"="Play Store"
 "org.telegram.messenger"="Telegram"
 "com.discord"="Discord"
 "com.snapchat.android"="Snapchat"
 "com.reddit.frontpage"="Reddit"
 "com.microsoft.office.outlook"="Outlook"
 "com.microsoft.teams"="Teams"
}
$script:AppWindows = @{}
$C = @{
 Bg=[Drawing.Color]::FromArgb(8,13,25); Side=[Drawing.Color]::FromArgb(8,15,29)
 Panel=[Drawing.Color]::FromArgb(17,27,44); Panel2=[Drawing.Color]::FromArgb(25,38,59)
 Line=[Drawing.Color]::FromArgb(44,60,83); Text=[Drawing.Color]::FromArgb(240,245,253)
 Muted=[Drawing.Color]::FromArgb(145,163,188); Blue=[Drawing.Color]::FromArgb(38,117,255)
 Green=[Drawing.Color]::FromArgb(17,159,117); Purple=[Drawing.Color]::FromArgb(117,77,203)
 Red=[Drawing.Color]::FromArgb(185,62,81)
}
$f=New-Object Windows.Forms.Form
$f.Text="DroidDesk v1.0 • USB + Wi-Fi"; $f.StartPosition="CenterScreen"; $f.ClientSize=New-Object Drawing.Size(1240,780)
$f.MinimumSize=New-Object Drawing.Size(960,650); $f.BackColor=$C.Bg; $f.ForeColor=$C.Text
$f.Font=New-Object Drawing.Font("Segoe UI",9)

function Label($txt,$x,$y,$w,$h,$size=9,$bold=$false,$color=$C.Text) {
 $o=New-Object Windows.Forms.Label; $o.Text=$txt; $o.Location=New-Object Drawing.Point($x,$y); $o.Size=New-Object Drawing.Size($w,$h)
 $style=if($bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}
 $o.Font=New-Object Drawing.Font("Segoe UI",$size,$style); $o.ForeColor=$color; $o.BackColor=[Drawing.Color]::Transparent; return $o
}
function Button($txt,$x,$y,$w,$h,$bg=$C.Panel2,$size=9) {
 $o=New-Object Windows.Forms.Button; $o.Text=$txt; $o.Location=New-Object Drawing.Point($x,$y); $o.Size=New-Object Drawing.Size($w,$h)
 $o.FlatStyle="Flat"; $o.FlatAppearance.BorderSize=0; $o.BackColor=$bg; $o.ForeColor=$C.Text
 $o.Font=New-Object Drawing.Font("Segoe UI",$size,[Drawing.FontStyle]::Bold); $o.Cursor=[Windows.Forms.Cursors]::Hand; return $o
}

function Set-Rounded($control,[int]$radius=10) {
 try {
  $w=[Math]::Max(1,$control.Width);$h=[Math]::Max(1,$control.Height)
  $path=New-Object Drawing.Drawing2D.GraphicsPath
  $d=$radius*2
  $path.AddArc(0,0,$d,$d,180,90)
  $path.AddArc(($w-$d),0,$d,$d,270,90)
  $path.AddArc(($w-$d),($h-$d),$d,$d,0,90)
  $path.AddArc(0,($h-$d),$d,$d,90,90)
  $path.CloseFigure()
  $control.Region=New-Object Drawing.Region($path)
  $path.Dispose()
 } catch {}
}
function Save-UserData {
 try {
  if(!(Test-Path $script:UserDataDir)){New-Item -ItemType Directory -Path $script:UserDataDir -Force | Out-Null}
  @{Favorites=@($script:Favorites);RecentApps=@($script:RecentApps | Select-Object -First 12)} |
   ConvertTo-Json -Depth 3 | Set-Content -Path $script:UserDataFile -Encoding UTF8
 } catch {}
}
function AppCategory([string]$pkg) {
 $p=$pkg.ToLowerInvariant()
 if($p -match 'whatsapp|facebook|messenger|telegram|instagram|snapchat|discord|reddit|tiktok|twitter|x\.com|wechat'){return "Social"}
 if($p -match 'chrome|browser|brave|firefox|opera|edge'){return "Browser"}
 if($p -match 'youtube|video|music|spotify|mxtech|vanced|netflix|media|camera|photo|snapseed'){return "Media"}
 if($p -match 'google|microsoft|office|docs|drive|calendar|mail|gmail|keep|maps|chatgpt|openai'){return "Productivity"}
 if($p -match 'game|play|hyperkani|stunt|pubg|freefire'){return "Games"}
 return "Tools"
}
function AppGlyph([string]$pkg) {
 $p=$pkg.ToLowerInvariant()
 if($p -match 'whatsapp'){return "WA"}
 if($p -match 'facebook.orca|messenger'){return "M"}
 if($p -match 'chrome|brave|browser'){return "◎"}
 if($p -match 'youtube'){return "▶"}
 if($p -match 'instagram'){return "IG"}
 if($p -match 'telegram'){return "TG"}
 if($p -match 'chatgpt|openai'){return "AI"}
 if($p -match 'spotify|music'){return "♫"}
 if($p -match 'camera|photo|snapseed'){return "◉"}
 if($p -match 'google|gmail|bard'){return "G"}
 $n=Friendly $pkg
 return $n.Substring(0,[Math]::Min(2,$n.Length)).ToUpper()
}
function Set-Status($txt,$color=$C.Muted){$status.Text=$txt;$status.ForeColor=$color}
function Adb([string[]]$CommandArgs) {
 if(!$script:AdbPath -or !(Test-Path $script:AdbPath)){
  Set-Status "Setup required: select scrcpy.exe from the complete scrcpy folder." $C.Red
  return $null
 }
 try {
  if($script:AdbSerial){
   $output=& $script:AdbPath -s $script:AdbSerial @CommandArgs 2>&1
  } else {
   $output=& $script:AdbPath @CommandArgs 2>&1
  }
  $script:LastAdbExitCode=$LASTEXITCODE
  $lines=@($output | ForEach-Object { "$_".TrimEnd() } | Where-Object { $_ -ne "" })
  if($lines.Count -gt 0){ return ($lines -join "`n") }
  return $null
 } catch {
  Set-Status ("ADB execution error: "+$_.Exception.Message) $C.Red
  return $null
 }
}
function Resolve-AppNames {

 if(!$script:AaptPath -or !(Test-Path $script:AaptPath)) {
  $folders = @()

  if($script:ScrcpyPath) {
   $folders += (Split-Path $script:ScrcpyPath -Parent)
  }

  if($PSScriptRoot) {
   $folders += $PSScriptRoot
  }

  foreach($folder in ($folders | Select-Object -Unique)) {
   $candidate = Join-Path $folder "aapt.exe"

   if(Test-Path $candidate) {
    $script:AaptPath = $candidate
    break
   }
  }
 }

 if(!$script:AaptPath -or !(Test-Path $script:AaptPath)) {
  Set-Status "Apps loaded • aapt.exe missing, using fallback names." $C.Muted
  return
 }

 $tempDir = Join-Path $env:TEMP "DroidDesk_AppLabels"

 if(!(Test-Path $tempDir)) {
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
 }

 $changed = $false
 $total = $script:Packages.Count
 $index = 0

 foreach($pkg in $script:Packages) {

  $index++

  if($script:AppNameCache.ContainsKey($pkg)) {
   continue
  }

  Set-Status "Detecting app names... $index / $total" $C.Muted

  try {
   $paths = Adb @("shell","pm","path",$pkg)

   if(!$paths) { continue }

   $remoteApk = $null

   foreach($line in ($paths -split "`r?`n")) {
    if($line -match '^package:(.+base\.apk)$') {
     $remoteApk = $Matches[1].Trim()
     break
    }
   }

   if(!$remoteApk) {
    foreach($line in ($paths -split "`r?`n")) {
     if($line -match '^package:(.+\.apk)$') {
      $remoteApk = $Matches[1].Trim()
      break
     }
    }
   }

   if(!$remoteApk) { continue }

   $safeName = [Guid]::NewGuid().ToString() + ".apk"
   $localApk = Join-Path $tempDir $safeName

   $pullArgs = @()

   if($script:AdbSerial) {
    $pullArgs += @("-s",$script:AdbSerial)
   }

   $pullArgs += @("pull",$remoteApk,$localApk)

   & $script:AdbPath @pullArgs 2>&1 | Out-Null

   if(!(Test-Path $localApk)) { continue }

   $badging = & $script:AaptPath dump badging $localApk 2>$null

   $label = $null

   foreach($line in $badging) {
    if("$line" -match "^application-label:'(.*)'$") {
     $label = $Matches[1].Trim()
     break
    }
   }

   if(!$label) {
    foreach($line in $badging) {
     if("$line" -match "^application-label-[^:]+:'(.*)'$") {
      $label = $Matches[1].Trim()
      break
     }
    }
   }

   if($label -and $label.Length -gt 0) {
    $script:AppNameCache[$pkg] = $label
    $changed = $true
   }

   Remove-Item $localApk -Force -ErrorAction SilentlyContinue

  } catch {
   continue
  }
 }

 if($changed) {
  try {
   if(!(Test-Path $script:UserDataDir)) {
    New-Item -ItemType Directory -Path $script:UserDataDir -Force | Out-Null
   }

   $script:AppNameCache |
    ConvertTo-Json -Depth 5 |
    Set-Content -Path $script:AppNameCacheFile -Encoding UTF8
  } catch {}
 }

 Set-Status "App names updated • $total apps scanned." ([Drawing.Color]::FromArgb(136,224,191))
}

function Get-ReadyAdbDevices {
 if(!$script:AdbPath -or !(Test-Path $script:AdbPath)){return @()}
 $output=& $script:AdbPath devices 2>&1
 $ready=@()
 foreach($line in ($output -split "`r?`n")){
  if($line -match '^([^\s]+)\s+device(?:\s|$)'){
   $serial=$Matches[1]
   if($serial -notmatch '^emulator-'){$ready += $serial}
  }
 }
 return @($ready | Select-Object -Unique)
}
function Verify-AdbDevice([string]$Serial) {
 if([string]::IsNullOrWhiteSpace($Serial)){return $false}
 $output=& $script:AdbPath -s $Serial get-state 2>&1
 $exit=$LASTEXITCODE
 $state=(@($output) -join "`n").Trim()
 return ($exit -eq 0 -and $state -eq "device")
}
function Friendly($pkg) {

 if($script:KnownApps.ContainsKey($pkg)) {
  return $script:KnownApps[$pkg]
 }

 if($script:AppNameCache.ContainsKey($pkg) -and
    ![string]::IsNullOrWhiteSpace($script:AppNameCache[$pkg])) {
  return $script:AppNameCache[$pkg]
 }

 $parts = $pkg.Split('.')
 $last = $parts[$parts.Length-1]

 if($last.Length -gt 0) {
  return ($last.Substring(0,1).ToUpper()+$last.Substring(1))
 }

 return $pkg
}
function Launch-App($pkg) {
 if(!$script:ScrcpyPath -or !(Test-Path $script:ScrcpyPath)){[Windows.Forms.MessageBox]::Show("Select scrcpy.exe in Setup first.","DroidDesk");return}
 try {
  $launchArgs=@("--new-display=1024x576","--start-app=$pkg","--max-fps=30","--video-bit-rate=4M")
  if($script:AdbSerial){$launchArgs += "--serial=$script:AdbSerial"}
  $proc=Start-Process -FilePath $script:ScrcpyPath -WorkingDirectory (Split-Path $script:ScrcpyPath -Parent) -ArgumentList $launchArgs -PassThru
  $script:AppWindows[$pkg]=$proc
  $script:RecentApps=@($pkg)+@($script:RecentApps | Where-Object {$_ -ne $pkg})
  $script:RecentApps=@($script:RecentApps | Select-Object -First 12)
  Save-UserData
  Set-Status ("Opening "+(Friendly $pkg)+" in its own desktop window.") ([Drawing.Color]::FromArgb(136,224,191))
 } catch {Set-Status "Could not launch app. Check scrcpy version and phone authorization." $C.Red}
}
function Toggle-Favorite($pkg) {
 if($script:Favorites -contains $pkg){$script:Favorites=@($script:Favorites | Where-Object {$_ -ne $pkg})}
 else {$script:Favorites=@($script:Favorites)+$pkg}
 Save-UserData
 Build-AppList
}
function Build-AppList {
 if(!$appList){return}
 $appList.SuspendLayout()
 $appList.Controls.Clear()
 $appList.FlowDirection=[Windows.Forms.FlowDirection]::LeftToRight
 $appList.WrapContents=$true
 $q=$search.Text.Trim().ToLowerInvariant()
 $items=@($script:Packages | Where-Object {
  $pkg=$_
  $name=(Friendly $pkg).ToLowerInvariant()
  $category=AppCategory $pkg
  (($name.Contains($q) -or $pkg.ToLowerInvariant().Contains($q)) -and
   ($script:CategoryFilter -eq "All" -or $category -eq $script:CategoryFilter) -and
   (!$script:FavoritesOnly -or $script:Favorites -contains $pkg) -and
   (!$script:RecentOnly -or $script:RecentApps -contains $pkg))
 } | Sort-Object { Friendly $_ })
 foreach($pkg in $items) {
  $name=Friendly $pkg
  $card=New-Object Windows.Forms.Panel
  $card.Size=New-Object Drawing.Size(196,108)
  $card.Margin=New-Object Windows.Forms.Padding(4,4,4,8)
  $card.BackColor=$C.Panel
  Set-Rounded $card 10
  $glyph=AppGlyph $pkg
  $tile=New-Object Windows.Forms.Panel
  $tile.Location=New-Object Drawing.Point(9,12)
  $tile.Size=New-Object Drawing.Size(42,42)
  $tile.BackColor=$C.Panel2
  Set-Rounded $tile 9
  $glyphLabel=Label $glyph 0 10 42 22 10 $true $C.Blue
  $glyphLabel.TextAlign="MiddleCenter"
  $tile.Controls.Add($glyphLabel)
  $card.Controls.Add($tile)
  $nameLabel=Label $name 59 9 128 22 9 $true $C.Text
  $nameLabel.AutoEllipsis=$true
  $card.Controls.Add($nameLabel)
  $categoryLabel=Label (AppCategory $pkg) 59 31 128 17 7 $false $C.Muted
  $card.Controls.Add($categoryLabel)
  $open=Button "Open" 59 56 91 27 $C.Blue 8
  Set-Rounded $open 7
  $p=$pkg
  $open.Add_Click({Launch-App $p}.GetNewClosure())
  $card.Controls.Add($open)
  $favText=if($script:Favorites -contains $pkg){"★"}else{"☆"}
  $fav=Button $favText 155 56 31 27 $C.Panel2 11
  Set-Rounded $fav 7
  $fav.Add_Click({Toggle-Favorite $p}.GetNewClosure())
  $card.Controls.Add($fav)
  $tip=New-Object Windows.Forms.ToolTip
  $tip.SetToolTip($card,$pkg);$tip.SetToolTip($nameLabel,$pkg)
  $appList.Controls.Add($card)
 }
 if($items.Count -eq 0){
  $msg=if($script:Packages.Count -eq 0){"Connect your phone, then press Refresh to discover apps."}else{"No apps match these filters. Try another category or search."}
  $appList.Controls.Add((Label $msg 14 16 590 32 9 $false $C.Muted))
 }
 if($appCount){$appCount.Text=("{0} APPS" -f $items.Count)}
 $appList.ResumeLayout()
}
function Show-WindowManager {
 $d=New-Object Windows.Forms.Form
 $d.Text="DroidDesk • Window Manager";$d.StartPosition="CenterParent";$d.ClientSize=New-Object Drawing.Size(470,390)
 $d.FormBorderStyle="FixedDialog";$d.MaximizeBox=$false;$d.BackColor=$C.Bg;$d.ForeColor=$C.Text
 $d.Controls.Add((Label "Open app windows" 20 18 400 30 18 $true $C.Text))
 $d.Controls.Add((Label "Manage DroidDesk scrcpy windows launched in this session." 21 49 420 22 9 $false $C.Muted))
 $list=New-Object Windows.Forms.ListBox;$list.Location=New-Object Drawing.Point(20,82);$list.Size=New-Object Drawing.Size(430,220)
 $list.BackColor=$C.Panel;$list.ForeColor=$C.Text;$list.BorderStyle="FixedSingle";$list.Font=New-Object Drawing.Font("Segoe UI",9)
 # Capture the script-scoped collection before creating the closure.
 $appWindows = $script:AppWindows
 $refreshList={
  $list.Items.Clear()
  foreach($key in @($appWindows.Keys)){
   $pr=$appWindows[$key]
   if($pr -and !$pr.HasExited){[void]$list.Items.Add((Friendly $key)+"  •  "+$key)}
   else {$appWindows.Remove($key)}
  }
 }.GetNewClosure()
 & $refreshList
 $d.Controls.Add($list)
 $close=Button "Close selected window" 20 320 205 38 $C.Red 9
 $close.Add_Click({
  if($list.SelectedItem){
   $line=[string]$list.SelectedItem
   $pkg=$line.Substring($line.IndexOf("•")+1).Trim()
   if($appWindows.ContainsKey($pkg)){
    try{$appWindows[$pkg].CloseMainWindow() | Out-Null;Start-Sleep -Milliseconds 250;if(!$appWindows[$pkg].HasExited){$appWindows[$pkg].Kill()}}catch{}
    $appWindows.Remove($pkg)
   }
   & $refreshList
  }
 }.GetNewClosure())
 $reload=Button "Refresh list" 240 320 105 38 $C.Panel2 9;$reload.Add_Click($refreshList)
 $done=Button "Done" 355 320 95 38 $C.Blue 9;$done.Add_Click({$d.Close()})
 $d.Controls.AddRange(@($close,$reload,$done))
 [void]$d.ShowDialog($f)
}
function Set-DeviceDisplay([string]$Name) {
 if(!$script:DeviceNameLabel){return}
 if([string]::IsNullOrWhiteSpace($Name)){
  $script:DeviceNameLabel.Text="No device connected"
  $script:DeviceNameLabel.ForeColor=$C.Muted
 } else {
  $script:DeviceNameLabel.Text=$Name.Trim()
  $script:DeviceNameLabel.ForeColor=$C.Text
 }
}
function Refresh-Apps {
 if(!$script:AdbPath -or !(Test-Path $script:AdbPath)){
  Set-Status "Setup required: select scrcpy.exe from the complete scrcpy folder." $C.Red
  return
 }
 # Validate the remembered serial. If stale, select a currently authorized device.
 if(!(Verify-AdbDevice $script:AdbSerial)){
  $script:AdbSerial=""
  $ready=Get-ReadyAdbDevices
  if($ready.Count -eq 0){
   Set-DeviceDisplay ""
   Set-Status "No authorized ADB device. Connect USB or Wireless Debugging first." $C.Red
   if($appCount){$appCount.Text="NOT CONNECTED"}
   return
  }
  # Prefer the direct IP:port wireless transport; both ADB transports may refer to one phone.
  $ipDevice=@($ready | Where-Object {$_ -match ':\d+$'})
  if($ipDevice.Count -gt 0){
   $script:AdbSerial=$ipDevice[0];$script:ConnectionMode="Wi-Fi"
  } else {
   $script:AdbSerial=$ready[0];$script:ConnectionMode="USB"
  }
  if(!(Verify-AdbDevice $script:AdbSerial)){
   Set-DeviceDisplay ""
   Set-Status "ADB sees the phone, but its selected transport did not pass get-state." $C.Red
   if($appCount){$appCount.Text="CONNECTION ERROR"}
   return
  }
 }
 $state=Adb @("get-state")
 if(($state -as [string]).Trim() -ne "device"){
  # Retry using fresh device enumeration; don't trust a stale remembered serial.
  $script:AdbSerial=""
  $ready=Get-ReadyAdbDevices
  $candidate=@($ready | Where-Object {$_ -match ':\d+$'}) | Select-Object -First 1
  if(!$candidate){$candidate=$ready | Select-Object -First 1}
  if(!$candidate -or !(Verify-AdbDevice $candidate)){
   Set-DeviceDisplay ""
   Set-Status "ADB connection verification failed. Device list and get-state disagree." $C.Red
   if($appCount){$appCount.Text="CONNECTION ERROR"}
   return
  }
  $script:AdbSerial=$candidate
  $state=Adb @("get-state")
 }
 if(($state -as [string]).Trim() -ne "device"){
  Set-DeviceDisplay ""
  Set-Status "ADB device is not ready. Check the selected device connection." $C.Red
  return
 }
 # Read the model from the connected Android device; never assume a model name.
 $deviceModel=Adb @("shell","getprop","ro.product.model")
 $deviceModel=(@($deviceModel) -join " ").Trim()
 if([string]::IsNullOrWhiteSpace($deviceModel)){
  $deviceModel=Adb @("shell","getprop","ro.product.brand")
  $deviceModel=(@($deviceModel) -join " ").Trim()
 }
 if([string]::IsNullOrWhiteSpace($deviceModel)){$deviceModel="Android device connected"}
 Set-DeviceDisplay $deviceModel
 # Query the primary Android user; this avoids the restricted itel OS user 999.
 $raw=Adb @("shell","pm","list","packages","--user","0","-3")
 $found=@()
 if($raw){
  foreach($line in ($raw -split "`r?`n")){
   if($line -match '^package:(.+)$'){$found += $Matches[1].Trim()}
  }
 }
 $script:Packages=@($found | Where-Object {$_ -match '^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$'} | Sort-Object -Unique)
 if($script:Packages.Count -eq 0){
  Build-AppList
  if($appCount){$appCount.Text="0 APPS FOUND"}
  Set-Status "Connected, but Android returned no third-party packages for user 0." $C.Red
  return
 }
 Resolve-AppNames
Build-AppList

if($appCount) {
 $appCount.Text = ($script:Packages.Count.ToString()+" INSTALLED APPS")
}
 $mode=$script:ConnectionMode
 if($mode -notin @("USB","Wi-Fi")){$mode="ADB"}
 Set-Status ("$mode connected • "+$script:Packages.Count+" installed apps found.") ([Drawing.Color]::FromArgb(136,224,191))
 if($setup){$setup.Text="✓ Connected"}
  if($connectionBadge){$connectionBadge.Text="✓ "+$mode;$connectionBadge.BackColor=$C.Green}
}
function Launch-ScreenCopy {
 if(!$script:ScrcpyPath -or !(Test-Path $script:ScrcpyPath)){
  [Windows.Forms.MessageBox]::Show("Select scrcpy.exe in Setup first.","DroidDesk") | Out-Null
  return
 }
 try {
  $a=@("--max-fps=30","--video-bit-rate=4M")
  if($script:AdbSerial){$a += "--serial=$script:AdbSerial"}
  Start-Process -FilePath $script:ScrcpyPath -WorkingDirectory (Split-Path $script:ScrcpyPath -Parent) -ArgumentList $a | Out-Null
  Set-Status "Screen Copy running • full phone mirroring and control." ([Drawing.Color]::FromArgb(136,224,191))
 } catch {Set-Status "Could not start scrcpy. Check the selected scrcpy folder." $C.Red}
}
function Connect-USB {
 if(!$script:AdbPath -or !(Test-Path $script:AdbPath)){Set-Status "Click Setup and select scrcpy.exe first." $C.Red;return}
 try {
  $devices=Get-ReadyAdbDevices
  $usb=@($devices | Where-Object {$_ -notmatch ':\d+$' -and $_ -notmatch '_adb-tls-connect_'})
  if($usb.Count -eq 0){Set-Status "No authorized USB device found. Unlock phone and accept USB debugging." $C.Red;return}
  $script:AdbSerial=$usb[0];$script:ConnectionMode="USB"
  if(!(Verify-AdbDevice $script:AdbSerial)){Set-Status "USB device found but get-state verification failed." $C.Red;return}
  Refresh-Apps
 } catch {Set-Status "Could not detect USB device. Check cable and debugging authorization." $C.Red}
}
function Connect-WiFi {
 if(!$script:AdbPath -or !(Test-Path $script:AdbPath)){Set-Status "Click Setup and select scrcpy.exe first." $C.Red;return}
 $ipport=[Microsoft.VisualBasic.Interaction]::InputBox("On phone: Developer options → Wireless debugging → Pair device with pairing code.`nEnter the IP address and PAIRING port shown in that popup (example 192.168.1.20:37123). PC and phone must be on the same Wi-Fi.","Pair DroidDesk over Wi-Fi","")
 if([string]::IsNullOrWhiteSpace($ipport)){return}
 $code=[Microsoft.VisualBasic.Interaction]::InputBox("Enter the 6-digit pairing code shown on the phone.","Wireless debugging code","")
 if([string]::IsNullOrWhiteSpace($code)){return}
 try {
  Set-Status "Pairing over Wi-Fi…" $C.Muted
  $pairOut=& $script:AdbPath pair $ipport.Trim() $code.Trim() 2>&1
  if((@($pairOut) -join "`n") -notmatch 'Successfully paired'){
   [Windows.Forms.MessageBox]::Show(((@($pairOut) -join "`n").Trim()+"`n`nUse the pairing port from the pairing-code popup."),"Wi-Fi pairing failed") | Out-Null
   Set-Status "Wi-Fi pairing failed. Check pairing address/code." $C.Red;return
  }
  $connect=[Microsoft.VisualBasic.Interaction]::InputBox("Pairing succeeded. Return to Wireless debugging main screen and enter the regular device IP:port (NOT the pairing port). Example: 192.168.1.101:41987","Connect wireless device","")
  if([string]::IsNullOrWhiteSpace($connect)){Set-Status "Paired. Enter the regular debugging IP:port to connect." $C.Muted;return}
  $connect=$connect.Trim()
  $conOut=& $script:AdbPath connect $connect 2>&1
  $conText=@($conOut) -join "`n"
  if($conText -match '(?i)connected to|already connected'){
   $script:AdbSerial=$connect;$script:ConnectionMode="Wi-Fi"
   if(Verify-AdbDevice $script:AdbSerial){
    Refresh-Apps
   } else {
    # ADB may already have a valid TLS transport for this same phone.
    $ready=Get-ReadyAdbDevices
    $alt=@($ready | Where-Object {$_ -match '_adb-tls-connect_'}) | Select-Object -First 1
    if($alt -and (Verify-AdbDevice $alt)){$script:AdbSerial=$alt;Refresh-Apps}
    else {Set-Status "ADB connected, but the new Wi-Fi serial failed get-state verification." $C.Red}
   }
  } else {
   # If already connected via a prior session, reuse the verified IP or TLS serial.
   $ready=Get-ReadyAdbDevices
   $alt=@($ready | Where-Object {$_ -match ':\d+$'}) | Select-Object -First 1
   if(!$alt){$alt=@($ready | Where-Object {$_ -match '_adb-tls-connect_'}) | Select-Object -First 1}
   if($alt -and (Verify-AdbDevice $alt)){$script:AdbSerial=$alt;$script:ConnectionMode="Wi-Fi";Refresh-Apps}
   else {[Windows.Forms.MessageBox]::Show(($conText.Trim()),"Wi-Fi connection failed") | Out-Null;Set-Status "Wi-Fi connection failed. Check the regular debugging port." $C.Red}
  }
 } catch {Set-Status "Wi-Fi setup failed. Ensure PC and phone share the same Wi-Fi." $C.Red}
}

function Control-Center {
 $d=New-Object Windows.Forms.Form; $d.Text="DroidDesk Control Center";$d.StartPosition="CenterParent";$d.ClientSize=New-Object Drawing.Size(390,530)
 $d.FormBorderStyle="FixedDialog";$d.MaximizeBox=$false;$d.BackColor=$C.Bg;$d.ForeColor=$C.Text
 $d.Controls.Add((Label "Control Center" 20 18 320 35 20 $true $C.Text))
 $d.Controls.Add((Label "Phone actions via USB / ADB" 21 53 330 20 9 $false $C.Muted))
 $controls=@(
  @{T="Wi-Fi ON";K="wifiOn";X=20;Y=90;Co=$C.Blue},@{T="Wi-Fi OFF";K="wifiOff";X=200;Y=90;Co=$C.Panel2},
  @{T="Bluetooth ON";K="btOn";X=20;Y=145;Co=$C.Blue},@{T="Bluetooth OFF";K="btOff";X=200;Y=145;Co=$C.Panel2},
  @{T="Home";K="home";X=20;Y=200;Co=$C.Panel2},@{T="Back";K="back";X=200;Y=200;Co=$C.Panel2},
  @{T="Recent apps";K="recent";X=20;Y=255;Co=$C.Panel2},@{T="Quick settings";K="quick";X=200;Y=255;Co=$C.Panel2},
  @{T="Notifications";K="notify";X=20;Y=310;Co=$C.Panel2},@{T="Lock / sleep";K="lock";X=200;Y=310;Co=$C.Red}
 )
 foreach($it in $controls){$b=Button $it.T $it.X $it.Y 165 42 $it.Co 9;$k=$it.K;$b.Add_Click({
  switch($k){
   "wifiOn" {$null=Adb @("shell","svc","wifi","enable")}
   "wifiOff" {$null=Adb @("shell","svc","wifi","disable")}
   "btOn" {$null=Adb @("shell","cmd","bluetooth_manager","enable")}
   "btOff" {$null=Adb @("shell","cmd","bluetooth_manager","disable")}
   "home" {$null=Adb @("shell","input","keyevent","KEYCODE_HOME")}
   "back" {$null=Adb @("shell","input","keyevent","KEYCODE_BACK")}
   "recent" {$null=Adb @("shell","input","keyevent","KEYCODE_APP_SWITCH")}
   "quick" {$null=Adb @("shell","cmd","statusbar","expand-settings")}
   "notify" {$null=Adb @("shell","cmd","statusbar","expand-notifications")}
   "lock" {$null=Adb @("shell","input","keyevent","KEYCODE_SLEEP")}
  }
 }.GetNewClosure());$d.Controls.Add($b)}
 $d.Controls.Add((Label "Some Android 15 / itel OS builds block radio and status-bar commands. ADB will report failures in the main status line." 20 378 345 65 8 $false $C.Muted))
 [void]$d.ShowDialog($f)
}

# Header
$header=New-Object Windows.Forms.Panel;$header.Location=New-Object Drawing.Point(0,0);$header.Size=New-Object Drawing.Size(1240,66);$header.Anchor="Top,Left,Right";$header.BackColor=$C.Bg;$f.Controls.Add($header)
$logo=New-Object Windows.Forms.Panel;$logo.Location=New-Object Drawing.Point(18,13);$logo.Size=New-Object Drawing.Size(38,38);$logo.BackColor=$C.Blue;$header.Controls.Add($logo);Set-Rounded $logo 7
$logo.Controls.Add((Label "D" 7 3 30 30 19 $true ([Drawing.Color]::White)))
$header.Controls.Add((Label "DroidDesk" 66 10 250 30 20 $true $C.Text))
$header.Controls.Add((Label "YOUR ANDROID. ON DESKTOP." 68 38 280 17 7 $true $C.Muted))
$header.Controls.Add((Label "v1.0" 300 19 45 20 8 $true $C.Blue))
$usbBtn=Button "USB Connect" 770 15 112 36 $C.Green 8;$usbBtn.Anchor="Top,Right";$usbBtn.Add_Click({Connect-USB});$header.Controls.Add($usbBtn)
$wifiBtn=Button "Wi-Fi Connect" 886 15 120 36 $C.Blue 8;$wifiBtn.Anchor="Top,Right";$wifiBtn.Add_Click({Connect-WiFi});$header.Controls.Add($wifiBtn)
$connectionBadge=Button "Not connected" 1010 15 120 36 $C.Panel2 8;$connectionBadge.Anchor="Top,Right";$header.Controls.Add($connectionBadge)
$setup=Button "⚙ Setup" 1134 15 80 36 $C.Panel2 8;$setup.Anchor="Top,Right"
$setup.Add_Click({
 $o=New-Object Windows.Forms.OpenFileDialog;$o.Title="Select scrcpy.exe";$o.Filter="scrcpy.exe|scrcpy.exe"
 if($o.ShowDialog() -eq "OK"){
  $script:ScrcpyPath=$o.FileName;$candidate=Join-Path (Split-Path $script:ScrcpyPath -Parent) "adb.exe"
$script:AaptPath = Join-Path (Split-Path $script:ScrcpyPath -Parent) "aapt.exe"
  if(Test-Path $candidate){$script:AdbPath=$candidate;$setup.Text="✓ Tools Ready";Set-Status "ADB tools ready • now connect USB or Wireless Debugging." $C.Muted}
  else{$script:AdbPath="";Set-Status "adb.exe missing. Download the complete scrcpy ZIP, not only scrcpy.exe." $C.Red}
 }
 });$header.Controls.Add($setup)
 Set-Rounded $usbBtn 8;Set-Rounded $wifiBtn 8;Set-Rounded $connectionBadge 8;Set-Rounded $setup 8

# Left dock
$dock=New-Object Windows.Forms.Panel;$dock.Location=New-Object Drawing.Point(0,66);$dock.Size=New-Object Drawing.Size(105,660);$dock.Anchor="Top,Bottom,Left";$dock.BackColor=$C.Side;$f.Controls.Add($dock)
$dock.Controls.Add((Label "DOCK" 18 12 65 20 8 $true $C.Muted))
$dockApps=@(
 @{T="All Apps";S="▦";Y=43;Co=$C.Blue;Action="all"},
 @{T="WhatsApp";S="WA";Y=105;Co=$C.Green;Action="com.whatsapp"},
 @{T="Messenger";S="M";Y=167;Co=$C.Blue;Action="com.facebook.orca"},
 @{T="Chrome";S="C";Y=229;Co=$C.Panel2;Action="com.android.chrome"},
 @{T="YouTube";S="▶";Y=291;Co=$C.Red;Action="com.google.android.youtube"},
 @{T="Control";S="⚙";Y=353;Co=$C.Panel2;Action="control"}
)
foreach($it in $dockApps){
 $tile=Button $it.S 27 $it.Y 50 40 $it.Co 11;$act=$it.Action
 $tile.Add_Click({if($act -eq "all"){$null=Refresh-Apps;$search.Focus()}elseif($act -eq "control"){Control-Center}else{Launch-App $act}}.GetNewClosure());$dock.Controls.Add($tile)
 $dock.Controls.Add((Label $it.T 4 ($it.Y+42) 97 17 7 $false $C.Muted))
}
$dock.Controls.Add((Label "DEVICE" 10 575 85 18 8 $true $C.Muted))
$script:DeviceNameLabel=Label "No device connected" 10 594 90 34 8 $true $C.Muted
$script:DeviceNameLabel.AutoEllipsis=$true
$dock.Controls.Add($script:DeviceNameLabel)

# Main area and top greeting
$main=New-Object Windows.Forms.Panel;$main.Location=New-Object Drawing.Point(105,66);$main.Size=New-Object Drawing.Size(1135,660);$main.Anchor="Top,Bottom,Left,Right";$main.BackColor=$C.Bg;$f.Controls.Add($main)
$welcome=New-Object Windows.Forms.Panel;$welcome.Location=New-Object Drawing.Point(22,18);$welcome.Size=New-Object Drawing.Size(1085,88);$welcome.Anchor="Top,Left,Right";$welcome.BackColor=$C.Panel;$main.Controls.Add($welcome);Set-Rounded $welcome 12
$welcome.Controls.Add((Label "Good evening  ✦" 18 11 600 29 17 $true $C.Text))
$welcome.Controls.Add((Label "Your Android apps, one desktop. Connect your phone to get started." 19 43 820 22 9 $false $C.Muted))
$quick=Button "Open Control Center" 880 25 180 38 $C.Blue 8;$quick.Anchor="Top,Right";$quick.Add_Click({Control-Center});$welcome.Controls.Add($quick)

# Two-column dashboard: app catalog left, tips/status right
$main.Controls.Add((Label "✦  A P P   L I B R A R Y" 24 121 300 20 8 $true $C.Muted))
$appCount=Label "WAITING FOR PHONE" 430 121 210 20 8 $true $C.Blue;$appCount.TextAlign="MiddleRight";$main.Controls.Add($appCount)
$search=New-Object Windows.Forms.TextBox;$search.Location=New-Object Drawing.Point(23,147);$search.Size=New-Object Drawing.Size(230,31);$search.Anchor="Top,Left";$search.Font=New-Object Drawing.Font("Segoe UI",10);$search.BackColor=$C.Panel;$search.ForeColor=$C.Text;$search.BorderStyle="FixedSingle";$main.Controls.Add($search)
$category=New-Object Windows.Forms.ComboBox
$category.Location=New-Object Drawing.Point(263,147);$category.Size=New-Object Drawing.Size(125,31)
$category.DropDownStyle="DropDownList";$category.BackColor=$C.Panel;$category.ForeColor=$C.Text
[void]$category.Items.AddRange(@("All","Social","Browser","Media","Productivity","Games","Tools"))
$category.SelectedIndex=0;$main.Controls.Add($category)
$favFilter=Button "☆ Favorites" 396 145 90 33 $C.Panel2 8;$favFilter.Add_Click({
 $script:FavoritesOnly=!$script:FavoritesOnly
 $favFilter.Text=if($script:FavoritesOnly){"★ Favorites"}else{"☆ Favorites"}
 Build-AppList
});$main.Controls.Add($favFilter)
$recentFilter=Button "Recent" 492 145 80 33 $C.Panel2 8
$recentFilter.Add_Click({
 $script:RecentOnly=!$script:RecentOnly
 $recentFilter.Text=if($script:RecentOnly){"Recent ✓"}else{"Recent"}
 Build-AppList
});$main.Controls.Add($recentFilter);Set-Rounded $recentFilter 8
$refresh=Button "↻ Refresh" 578 145 84 33 $C.Panel2 8;$refresh.Anchor="Top,Right";$refresh.Add_Click({Refresh-Apps});$main.Controls.Add($refresh);Set-Rounded $refresh 8
$appList=New-Object Windows.Forms.FlowLayoutPanel;$appList.Location=New-Object Drawing.Point(23,190);$appList.Size=New-Object Drawing.Size(640,390);$appList.Anchor="Top,Bottom,Left,Right";$appList.AutoScroll=$true;$appList.WrapContents=$true;$appList.FlowDirection="LeftToRight";$appList.BackColor=$C.Bg;$main.Controls.Add($appList)
$appList.Controls.Add((Label "Connect your phone, then press Refresh to discover launchable apps." 12 12 600 30 9 $false $C.Muted))
$status=Label "Not connected • Choose USB Connect or Wi-Fi Connect to begin." 24 610 1050 25 9 $false $C.Muted;$status.Anchor="Bottom,Left,Right";$main.Controls.Add($status)
$search.Add_TextChanged({Build-AppList})
$category.Add_SelectedIndexChanged({$script:CategoryFilter=[string]$category.SelectedItem;Build-AppList})

$sidecard=New-Object Windows.Forms.Panel;$sidecard.Location=New-Object Drawing.Point(688,121);$sidecard.Size=New-Object Drawing.Size(419,490);$sidecard.Anchor="Top,Bottom,Right";$sidecard.BackColor=$C.Panel;$main.Controls.Add($sidecard);Set-Rounded $sidecard 12
$sidecard.Controls.Add((Label "✦  Q U I C K   C O N T R O L S" 18 17 300 20 8 $true $C.Muted))
$sidecard.Controls.Add((Label "Manage your phone from your PC" 18 43 370 26 13 $true $C.Text))
$ctrlBtn=Button "Open Control Center  →" 18 80 380 42 $C.Blue 9;$ctrlBtn.Anchor="Top,Left,Right";$ctrlBtn.Add_Click({Control-Center});$sidecard.Controls.Add($ctrlBtn)
$sidecard.Controls.Add((Label "PINNED APPS" 18 145 300 20 8 $true $C.Muted))
$quickApps=@(
 @{T="WhatsApp";P="com.whatsapp";Y=177;Co=$C.Green},
 @{T="Messenger";P="com.facebook.orca";Y=226;Co=$C.Blue},
 @{T="Chrome";P="com.android.chrome";Y=275;Co=$C.Panel2},
 @{T="YouTube";P="com.google.android.youtube";Y=324;Co=$C.Red}
)
foreach($it in $quickApps){$bb=Button ("  "+$it.T+"     Open ↗") 18 $it.Y 380 40 $it.Co 9;$bb.Anchor="Top,Left,Right";$pk=$it.P;$bb.Add_Click({Launch-App $pk}.GetNewClosure());$sidecard.Controls.Add($bb)}
$windowBtn=Button "Manage open windows  ›" 18 354 380 36 $C.Panel2 9;$windowBtn.Anchor="Top,Left,Right";$windowBtn.Add_Click({Show-WindowManager});$sidecard.Controls.Add($windowBtn)
$screenBtn=Button "Screen Copy  •  Full Mirroring" 18 397 380 34 $C.Purple 9;$screenBtn.Anchor="Top,Left,Right";$screenBtn.Add_Click({Launch-ScreenCopy});$sidecard.Controls.Add($screenBtn)
$sidecard.Controls.Add((Label "✦  LIGHTWEIGHT MODE   ·   30 FPS   ·   4 Mbps" 18 435 380 18 8 $true $C.Muted))

# Bottom in-app taskbar
$task=New-Object Windows.Forms.Panel;$task.Location=New-Object Drawing.Point(0,726);$task.Size=New-Object Drawing.Size(1240,54);$task.Anchor="Bottom,Left,Right";$task.BackColor=$C.Panel;$f.Controls.Add($task)
$task.Controls.Add((Label "▦" 20 13 35 25 15 $true $C.Text))
$task.Controls.Add((Label "DroidDesk" 54 16 120 20 9 $true $C.Text))
$task.Controls.Add((Label "ADB  •  DeX-inspired workspace" 180 16 260 20 8 $false $C.Muted))
$wa=Button "WA" 430 7 43 38 $C.Green 8;$wa.Add_Click({Launch-App "com.whatsapp"});$task.Controls.Add($wa)
$me=Button "M" 480 7 43 38 $C.Blue 8;$me.Add_Click({Launch-App "com.facebook.orca"});$task.Controls.Add($me)
$chr=Button "C" 530 7 43 38 $C.Panel2 8;$chr.Add_Click({Launch-App "com.android.chrome"});$task.Controls.Add($chr)
$ctrlTask=Button "☷ Control Center" 930 7 130 38 $C.Panel2 8;$ctrlTask.Anchor="Top,Right";$ctrlTask.Add_Click({Control-Center});$task.Controls.Add($ctrlTask)
$appsTask=Button "▦ All Apps" 1068 7 145 38 $C.Blue 8;$appsTask.Anchor="Top,Right";$appsTask.Add_Click({Refresh-Apps});$task.Controls.Add($appsTask)

function Update-DroidDeskLayout {
 if(!$f -or $f.IsDisposed){return}
 $cw=$f.ClientSize.Width
 $ch=$f.ClientSize.Height
 if($cw -lt 300 -or $ch -lt 300){return}

 $header.Width=$cw
 $dock.Height=$ch-120
 $main.Location=[Drawing.Point]::new(105,66)
 $main.Size=[Drawing.Size]::new([Math]::Max(100,$cw-105),[Math]::Max(100,$ch-120))
 $task.Location=[Drawing.Point]::new(0,$ch-54)
 $task.Size=[Drawing.Size]::new($cw,54)

 # Header actions stay aligned to the right and never overlap the brand.
 $setup.Location=[Drawing.Point]::new($cw-98,15)
 $connectionBadge.Location=[Drawing.Point]::new($cw-226,15)
 $wifiBtn.Location=[Drawing.Point]::new($cw-354,15)
 $usbBtn.Location=[Drawing.Point]::new($cw-474,15)

 # Dock device details sit above the fixed taskbar.
 $deviceY=[Math]::Max(430,$dock.Height-58)
 $deviceHeading=$dock.Controls | Where-Object { $_ -is [Windows.Forms.Label] -and $_.Text -eq 'DEVICE' } | Select-Object -First 1
 if($deviceHeading){$deviceHeading.Location=[Drawing.Point]::new(10,$deviceY)}
 $script:DeviceNameLabel.Location=[Drawing.Point]::new(10,$deviceY+19)

 $mw=$main.ClientSize.Width
 $mh=$main.ClientSize.Height
 $welcome.Width=[Math]::Max(300,$mw-44)
 $quick.Location=[Drawing.Point]::new([Math]::Max(120,$welcome.Width-198),25)

 # The right panel is shown only when there is enough horizontal room.
 $showSide=($mw -ge 1150)
 $sidecard.Visible=$showSide
 if($showSide){
  $sideW=[Math]::Min(400,[Math]::Max(340,[int]($mw*0.32)))
  $sideX=$mw-$sideW-22
  $leftW=[Math]::Max(420,$sideX-41)
  $sidecard.Location=[Drawing.Point]::new($sideX,121)
  $sidecard.Size=[Drawing.Size]::new($sideW,[Math]::Max(300,$mh-121-12))
 } else {
  $leftW=[Math]::Max(420,$mw-46)
  $sidecard.Size=[Drawing.Size]::new(0,0)
 }

 # Toolbar controls use the available library width.
 $appCount.Location=[Drawing.Point]::new([Math]::Max(300,$leftW-230),121)
 $appCount.Width=210
 $refresh.Location=[Drawing.Point]::new([Math]::Max(580,$leftW-84),145)
 $appList.Location=[Drawing.Point]::new(23,190)
 $appList.Size=[Drawing.Size]::new($leftW,[Math]::Max(160,$mh-235))
 $status.Location=[Drawing.Point]::new(24,$mh-35)
 $status.Width=[Math]::Max(300,$mw-48)

 if($showSide){
  $innerW=$sidecard.ClientSize.Width-36
  $ctrlBtn.Width=$innerW
  $windowBtn.Width=$innerW
  $screenBtn.Width=$innerW
  foreach($control in $sidecard.Controls){
   if($control -is [Windows.Forms.Button] -and $control -notin @($ctrlBtn,$windowBtn,$screenBtn)){
    $control.Width=$innerW
   }
  }
 }

 # Right-side taskbar actions remain grouped at the lower-right corner.
 $appsTask.Location=[Drawing.Point]::new($cw-152,7)
 $ctrlTask.Location=[Drawing.Point]::new($cw-290,7)
}

$f.Add_Shown({
 Set-Rounded $welcome 12;Set-Rounded $sidecard 12;Set-Rounded $logo 7
 Set-Rounded $refresh 8;Set-Rounded $favFilter 8;Set-Rounded $recentFilter 8
 foreach($b in @($ctrlBtn,$quick,$appsTask,$ctrlTask)){Set-Rounded $b 8}
 Update-DroidDeskLayout
})
$f.Add_Resize({Update-DroidDeskLayout})

# Keep the device label synchronized with ADB connection state.
$deviceMonitor=New-Object Windows.Forms.Timer
$deviceMonitor.Interval=2500
$deviceMonitor.Add_Tick({
 if($script:AdbPath -and (Test-Path $script:AdbPath)) {
  if($script:AdbSerial) {
   if(!(Verify-AdbDevice $script:AdbSerial)) {
    $script:AdbSerial=""
    Set-DeviceDisplay ""
    if($appCount){$appCount.Text="WAITING FOR PHONE"}
    Set-Status "Phone disconnected • connect USB or Wi-Fi to continue." $C.Muted
   }
  } else {
   $available=Get-ReadyAdbDevices
   if($available.Count -gt 0) { Refresh-Apps }
  }
 }
})
$deviceMonitor.Start()

# Show the DroidDesk window.
[void]$f.ShowDialog()
$deviceMonitor.Stop()
$deviceMonitor.Dispose()
