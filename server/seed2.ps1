$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8090/api'
$auth = @{ identity = 'admin@vibe.local'; password = 'VibeAdmin2026!' } | ConvertTo-Json
$r = Invoke-RestMethod -Uri "$base/collections/_superusers/auth-with-password" -Method Post -ContentType 'application/json' -Body $auth
$h = @{ Authorization = "Bearer $($r.token)" }

function New-Record($col, $body) {
  Invoke-RestMethod -Uri "$base/collections/$col/records" -Method Post -Headers $h -ContentType 'application/json' -Body $body
}

# РњРѕР№ РґРµРјРѕ-РїСЂРѕС„РёР»СЊ (id СЃРѕС…СЂР°РЅСЏРµРј)
$me = Invoke-RestMethod -Uri "$base/collections/profiles/records?filter=username='andrey'" -Headers $h
if ($me.items.Count -eq 0) {
  $me = New-Record 'profiles' (@{ username = 'andrey'; displayName = 'РђРЅРґСЂРµР№'; online = $true } | ConvertTo-Json)
} else { $me = $me.items[0] }
Write-Output "ME=$($me.id)"

# РљРѕРЅС‚Р°РєС‚С‹
$names = @('Aurion','РђР»РёСЃР° РљРёРј','РљРѕРјР°РЅРґР° Vibe','РњР°СЂРє РћСЃРёРїРѕРІ','РЎС‚СѓРґРёСЏ Р’Р°Р№Р±РёРєР°','РљСЂРёРїС‚РѕРЅРѕРІРѕСЃС‚Рё','Daria Store','РЎРµРјСЊСЏ','РљРѕРґРµСЂ РҐР°СѓСЃ','РќРёРєР° Р›.','Р”РёРјР° Р‘.','РЎРѕРЅСЏ Р.','Р РµС‚СЂРѕ-С‡Р°Р№','Р“РѕР»РѕСЃРѕРІРѕР№ Р•Р¶','РўСѓСЃРѕРІРєР° DJ Nord')
$kinds = @('pm','pm','group','pm','channel','channel','biz','group','group','pm','pm','pm','biz','channel','group')
for ($i = 0; $i -lt $names.Count; $i++) {
  $display = $names[$i]
  $username = ($display -replace '[^a-zA-ZРђ-РЇР°-СЏ]','').ToLower() + '_seed'
  $exists = Invoke-RestMethod -Uri "$base/collections/profiles/records?filter=username='$username'" -Headers $h
  $pid2 = if ($exists.items.Count -gt 0) { $exists.items[0].id } else {
    (New-Record 'profiles' (@{ username = $username; displayName = $display; online = ($i % 3 -eq 0) } | ConvertTo-Json)).id
  }
  # chat СЃ СѓС‡Р°СЃС‚РЅРёРєР°РјРё [me, pid]
  $chatId = (New-Record 'chats' (@{ title = $display; kind = $kinds[$i]; members = @($me.id, $pid) } | ConvertTo-Json)).id
  Write-Output "CHAT $display => $chatId"
}

# РїР°СЂР° СЃС‚Р°СЂС‚РѕРІС‹С… СЃРѕРѕР±С‰РµРЅРёР№ РґР»СЏ РїРµСЂРІРѕРіРѕ С‡Р°С‚Р° (РёС‰РµРј С‡Р°С‚ СЃ Aurione)
$aur = Invoke-RestMethod -Uri "$base/collections/profiles/records?filter=username='aurinРµ_seed'" -Headers $h
Write-Output "SEED_DONE me=$($me.id)"