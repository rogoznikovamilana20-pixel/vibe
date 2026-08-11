$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8090/api'
$auth = @{ identity = 'admin@vibe.local'; password = 'VibeAdmin2026!' } | ConvertTo-Json
$r = Invoke-RestMethod -Uri "$base/collections/_superusers/auth-with-password" -Method Post -ContentType 'application/json' -Body $auth
$h = @{ Authorization = "Bearer $($r.token)" }

function New-Record($col, $body) {
  Invoke-RestMethod -Uri "$base/collections/$col/records" -Method Post -Headers $h -ContentType 'application/json' -Body $body
}

# Мой демо-профиль (id сохраняем)
$me = Invoke-RestMethod -Uri "$base/collections/profiles/records?filter=username='andrey'" -Headers $h
if ($me.items.Count -eq 0) {
  $me = New-Record 'profiles' (@{ username = 'andrey'; displayName = 'Андрей'; online = $true } | ConvertTo-Json)
} else { $me = $me.items[0] }
Write-Output "ME=$($me.id)"

# Контакты
$names = @('Aurion','Алиса Ким','Команда Vibe','Марк Осипов','Студия Вайбика','Криптоновости','Daria Store','Семья','Кодер Хаус','Ника Л.','Дима Б.','Соня И.','Ретро-чай','Голосовой Еж','Тусовка DJ Nord')
$kinds = @('pm','pm','group','pm','channel','channel','biz','group','group','pm','pm','pm','biz','channel','group')
for ($i = 0; $i -lt $names.Count; $i++) {
  $display = $names[$i]
  $username = ($display -replace '[^a-zA-ZА-Яа-я]','').ToLower() + '_seed'
  $exists = Invoke-RestMethod -Uri "$base/collections/profiles/records?filter=username='$username'" -Headers $h
  $pid2 = if ($exists.items.Count -gt 0) { $exists.items[0].id } else {
    (New-Record 'profiles' (@{ username = $username; displayName = $display; online = ($i % 3 -eq 0) } | ConvertTo-Json)).id
  }
  # chat с участниками [me, pid]
  $chatId = (New-Record 'chats' (@{ title = $display; kind = $kinds[$i]; members = @($me.id, $pid) } | ConvertTo-Json)).id
  Write-Output "CHAT $display => $chatId"
}

# пара стартовых сообщений для первого чата (ищем чат с Aurione)
$aur = Invoke-RestMethod -Uri "$base/collections/profiles/records?filter=username='aurinе_seed'" -Headers $h
Write-Output "SEED_DONE me=$($me.id)"