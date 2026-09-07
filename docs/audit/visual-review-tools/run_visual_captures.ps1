$ErrorActionPreference = 'Stop'
$godotVisual = 'C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe'
$repoVisual = 'C:/Users/Kev/Documents/protocol'
$outVisual = "$repoVisual/docs/visuals/2026-09-06"
$jobsVisual = @(
 @('title','menu_ui_capture',''),
 @('first-run','menu_ui_capture','--capture-first-run'),
 @('roster','home_screen_capture','--capture-unlock-all-mem --capture-select-units=combat,avalanche,medic'),
 @('battle-idle','battle_ui_capture','--capture-no-primers'),
 @('battle-planning','battle_ui_capture','--capture-rolled --capture-lock-targets=3 --capture-no-primers --capture-protocol=8'),
 @('battle-status','battle_ui_capture','--capture-rolled --capture-hero-chips --capture-no-primers --capture-protocol=8 --capture-insets=132,56'),
 @('battle-inspect','battle_ui_capture','--capture-inspect-hero --capture-no-primers'),
 @('loadout','battle_ui_capture','--capture-loadout --capture-relics=twinFates,ironCurtain --capture-hero-gear=predator_lens,combat_plating --capture-no-primers'),
 @('help','battle_ui_capture','--capture-help=basics --capture-no-primers'),
 @('tutorial','battle_ui_capture','--capture-tutorial --capture-tutorial-step=1'),
 @('reward','reward_screen_capture','--capture-force-items=predator_lens,deep_zero_pin,patch_kit --capture-select=0'),
 @('fork','choice_screen_capture','--capture-screen=fork'),
 @('victory','run_end_capture','--capture-result=victory'),
 @('defeat','run_end_capture','--capture-result=defeat'),
 @('directive','directive_picker_capture',''),
 @('evolution','choice_screen_capture2',''),
 @('unlock','unlock_screen_capture','')
)
foreach ($jobVisual in $jobsVisual) {
 $nameVisual=$jobVisual[0]; $scriptVisual=$jobVisual[1]; $extraVisual=$jobVisual[2]
 $textVisual=Get-Content -LiteralPath "$repoVisual/scripts/debug/$scriptVisual.gd" -Raw
 $textVisual=$textVisual.Replace('func _initialize() -> void:', "func _initialize() -> void:`n`troot.size = Vector2i(540, 1200)`n`troot.content_scale_size = Vector2i(1080, 2400)")
 $textVisual=$textVisual.Replace('HelpMenu.open(', '(load("res://scripts/ui/help_menu.gd")).open(')
 $textVisual=$textVisual.Replace('res://debug_artifacts/battle_ui/directive_picker.png', 'res://docs/visuals/2026-09-06/directive.png')
 $textVisual=$textVisual -replace 'res://debug_artifacts/battle_ui/evolution_rows.png', "res://docs/visuals/2026-09-06/$nameVisual.png"
 $textVisual=$textVisual -replace 'res://debug_artifacts/directive_picker.png', "res://docs/visuals/2026-09-06/$nameVisual.png"
 Set-Content -LiteralPath "$repoVisual/debug_artifacts/visual_$nameVisual.gd" -Value $textVisual -Encoding utf8
 $argVisual="--path $repoVisual --rendering-method gl_compatibility --resolution 540x1200 -s res://debug_artifacts/visual_$nameVisual.gd --capture-output=res://docs/visuals/2026-09-06/$nameVisual.png $extraVisual"
 $processVisual=Start-Process -FilePath $godotVisual -ArgumentList $argVisual -WindowStyle Hidden -PassThru -RedirectStandardOutput "$repoVisual/debug_artifacts/visual_$nameVisual.log" -RedirectStandardError "$repoVisual/debug_artifacts/visual_$nameVisual.err"
 if (!$processVisual.WaitForExit(25000)) { Stop-Process -Id $processVisual.Id; Write-Output "TIMEOUT $nameVisual" } else { Write-Output "CAPTURE $nameVisual exit=$($processVisual.ExitCode)" }
}
