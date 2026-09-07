$repoVisual='C:/Users/Kev/Documents/protocol'
$exeVisual='C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe'
$extraJobsVisual=@(
 @('battle-390','battle_ui_capture',390,844,'--capture-rolled --capture-lock-targets=3 --capture-no-primers --capture-protocol=8'),
 @('battle-432','battle_ui_capture',432,960,'--capture-rolled --capture-lock-targets=3 --capture-no-primers --capture-protocol=8'),
 @('battle-twin','battle_ui_capture',540,1200,'--capture-rolled --capture-lock-targets=3 --capture-no-primers --capture-relics=twinFates --capture-protocol=8'),
 @('settings','battle_ui_capture',540,1200,'--capture-help=settings --capture-no-primers'),
 @('rewards-unselected','reward_screen_capture',540,1200,'--capture-force-items=predator_lens,deep_zero_pin,patch_kit'),
 @('relics','reward_screen_capture',540,1200,'--capture-force-items=twinFates,ironCurtain,rootAccess'),
 @('feedback-nudge','main_menu_capture',540,1200,'--capture-nudge')
)
foreach($jobVisual in $extraJobsVisual){
 $nameVisual=$jobVisual[0];$sourceVisual=$jobVisual[1];$wVisual=$jobVisual[2];$hVisual=$jobVisual[3];$argsVisual=$jobVisual[4]
 $bodyVisual=Get-Content "$repoVisual/scripts/debug/$sourceVisual.gd" -Raw
 $bodyVisual=$bodyVisual.Replace('HelpMenu.open(', '(load("res://scripts/ui/help_menu.gd")).open(')
 $bodyVisual=$bodyVisual.Replace('func _initialize() -> void:', "func _initialize() -> void:`n`troot.size = Vector2i($wVisual, $hVisual)`n`troot.content_scale_size = Vector2i(1080, 2400)")
 $bodyVisual=$bodyVisual.Replace('func _run_capture() -> void:', "func _run_capture() -> void:`n`tawait process_frame`n`troot.size = Vector2i($wVisual, $hVisual)`n`troot.content_scale_size = Vector2i(1080, 2400)")
 Set-Content "$repoVisual/debug_artifacts/visual_$nameVisual.gd" $bodyVisual -Encoding utf8
 $pVisual=Start-Process -FilePath $exeVisual -ArgumentList "--path $repoVisual --rendering-method gl_compatibility -s res://debug_artifacts/visual_$nameVisual.gd --capture-output=res://docs/visuals/2026-09-06/$nameVisual.png $argsVisual" -WindowStyle Hidden -PassThru -RedirectStandardOutput "$repoVisual/debug_artifacts/visual_$nameVisual.log" -RedirectStandardError "$repoVisual/debug_artifacts/visual_$nameVisual.err"
 if(!$pVisual.WaitForExit(25000)){Stop-Process -Id $pVisual.Id; Write-Output "TIMEOUT $nameVisual"}else{Write-Output "CAPTURE $nameVisual"}
}
