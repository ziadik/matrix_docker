$users = @(
    @{username="user1"; password="User12345"; admin=$false}
)
# shmigel
# zakovryazhin
# zyadik
# valentyukevich
# kovalenko
# bachinsky
# tsiganov
# leontev
# alferov
# lazutochkin

foreach ($user in $users) {
    Write-Host "Creating $($user.username)..." -ForegroundColor Yellow
    
    $adminFlag = if ($user.admin) { "-admin" } else { "" }
    
    # Ключевой момент: используем cmd /c с echo и передаем через stdin
    $password = $user.password
    $cmd = @"
    docker exec -it dendrite_server /usr/bin/create-account -config /etc/dendrite/dendrite.yaml -username $($user.username) -password $($user.password) 
"@
    
    # Выполняем команду через cmd
    cmd /c $cmd
    
    Write-Host "✓ Created $($user.username)" -ForegroundColor Green
    Start-Sleep -Seconds 1
}