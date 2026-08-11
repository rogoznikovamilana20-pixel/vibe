$ErrorActionPreference = 'Stop'
$base = 'http://127.0.0.1:8090/api'
$auth = @{ identity = 'admin@vibe.local'; password = 'VibeAdmin2026!' } | ConvertTo-Json
$r = Invoke-RestMethod -Uri "$base/collections/_superusers/auth-with-password" -Method Post -ContentType 'application/json' -Body $auth
$h = @{ Authorization = "Bearer $($r.token)" }
function New-Record($col, $body) {
  Invoke-RestMethod -Uri "$base/collections/$col/records" -Method Post -Headers $h -ContentType 'application/json' -Body $body
}
$me = Invoke-RestMethod -Uri "$base/collections/profiles/records?filter=username='andrey'" -Headers $h
if ($me.items.Count -eq 0) {
  $me = New-Record 'profiles' (@{ username = 'andrey'; displayName = 'HTML_ANDREY'; online = $true } | ConvertTo-Json)
} else { $me = $me.items[0] }