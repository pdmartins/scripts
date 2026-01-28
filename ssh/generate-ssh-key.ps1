param(
    [string]$Email,
    [string]$Name
)

# Função para verificar e tratar chaves existentes
function Resolve-ExistingKey {
    param(
        [string]$KeyName,
        [string]$SshDirectory
    )
    
    # Remover prefixo "id_" se o usuário digitou
    if ($KeyName.StartsWith("id_")) {
        $KeyName = $KeyName.Substring(3)
    }
    
    $KeyPath = Join-Path $SshDirectory "id_$KeyName"
    
    # Se a chave não existe, retorna o nome
    if (-not (Test-Path $KeyPath)) {
        return $KeyName
    }
    
    # Chave existe - exibir informações
    Write-Host "`n⚠️  A chave '$KeyPath' já existe!" -ForegroundColor Yellow
    
    # Exibir conteúdo da chave pública existente
    $PublicKeyPath = "$KeyPath.pub"
    if (Test-Path $PublicKeyPath) {
        Write-Host "`n📄 Conteúdo da chave pública existente:" -ForegroundColor Cyan
        Get-Content $PublicKeyPath | Write-Host -ForegroundColor White
    }
    
    Write-Host "`n🤔 O que deseja fazer?" -ForegroundColor Gray
    Write-Host "  ↩️ ENTER - Reescrever o arquivo existente" -ForegroundColor Gray
    Write-Host "  ✏️ Digite um novo nome - Gerar com outro nome" -ForegroundColor Gray
    Write-Host "  ⛔ Digite 'sair' ou pressione Ctrl+C para cancelar" -ForegroundColor Gray
    
    # Capturar a entrada
    Write-Host "`n👉 Digite: "-NoNewline  -ForegroundColor Gray
    $Response = $Host.UI.ReadLine()
    
    if ([string]::IsNullOrWhiteSpace($Response)) {
        # ENTER pressionado - reescrever
        Write-Host "`n🔄 Reescrevendo o arquivo existente..." -ForegroundColor Yellow
        return $KeyName
    }
    elseif ($Response.ToLower() -eq "sair" `
            -or $Response.ToLower() -eq "s" `
            -or $Response.ToLower() -eq "stop") {
        # "sair" digitado
        Write-Host "`n❌ Operação cancelada." -ForegroundColor Red
        exit
    }
    else {
        # Novo nome digitado - verificar recursivamente
        return Resolve-ExistingKey -KeyName $Response -SshDirectory $SshDirectory
    }
}

# Se o email não foi fornecido, solicitar
if ([string]::IsNullOrWhiteSpace($Email)) {
    $Email = Read-Host "📧 Digite o email"
}

# Extrair o prefixo do email
$EmailPrefix = $Email.Split('@')[0]

# Se o nome não foi fornecido, solicitar
if ([string]::IsNullOrWhiteSpace($Name)) {
    Write-Host "🔑 Digite o nome da chave (deixe em branco para usar " -NoNewline  -ForegroundColor Gray
    Write-Host $EmailPrefix -ForegroundColor Yellow -NoNewline
    Write-Host "): " -NoNewline  -ForegroundColor Gray
    $Name = Read-Host
}

# Se o nome estiver em branco, usar o prefixo antes do @ do email
if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = $EmailPrefix
    Write-Host "✨ Usando '" -ForegroundColor Gray -NoNewline
	Write-Host $EmailPrefix -ForegroundColor Yellow -NoNewline
	Write-Host "' como nome da chave (extraído do email)"  -ForegroundColor Gray
}

# Remover prefixo "id_" se o usuário digitou
if ($Name.StartsWith("id_")) {
    $Name = $Name.Substring(3)
    Write-Host "📌 Removido prefixo 'id_' duplicado. Usando: $Name" -ForegroundColor Yellow
}

# Construir o caminho completo do arquivo (sempre em ~/.ssh)
$SshDir = Join-Path $env:USERPROFILE ".ssh"
if (-not (Test-Path $SshDir)) {
    New-Item -ItemType Directory -Path $SshDir -Force | Out-Null
    Write-Host "📁 Diretório .ssh criado em: $SshDir" -ForegroundColor Green
}

# Verificar e resolver nome da chave (tratando duplicatas)
$Name = Resolve-ExistingKey -KeyName $Name -SshDirectory $SshDir
$KeyPath = Join-Path $SshDir "id_$Name"

Write-Host "`n🔐 Gerando chave SSH id_$Name" -ForegroundColor Cyan
Write-Host "📝 ssh-keygen -t ed25519 -C `"$Email`" -f `"$KeyPath`" -N `"`"`n" -ForegroundColor White

# Executar o ssh-keygen (com passphrase vazia e sobrescrever sem perguntar)
echo y | ssh-keygen -t ed25519 -C $Email -f $KeyPath -N ""

# Verificar se a chave foi gerada com sucesso
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=================================" -ForegroundColor Green
    Write-Host "✅ Chave SSH gerada com sucesso!" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    
    # Exibir o conteúdo da chave pública
    $PublicKeyPath = "$KeyPath.pub"
    
    if (Test-Path $PublicKeyPath) {
        Write-Host "`n📋 Conteúdo da chave pública (copie o texto abaixo):" -ForegroundColor Cyan
        Get-Content $PublicKeyPath | Write-Host -ForegroundColor White
    } else {
        Write-Host "`n⚠️  Aviso: Não foi possível encontrar o arquivo da chave pública em: $PublicKeyPath" -ForegroundColor Red
    }
} else {
    Write-Host "`n❌ Erro ao gerar a chave SSH!" -ForegroundColor Red
}