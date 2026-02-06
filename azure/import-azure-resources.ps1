<#
.SYNOPSIS
    Importa recursos Azure a partir de um ARM Template exportado.

.DESCRIPTION
    Este script conecta em um tenant Azure de destino, cria um novo Resource Group
    e faz o deploy dos recursos a partir de um ARM Template previamente exportado.

.PARAMETER TenantId
    ID do tenant Azure de destino.

.PARAMETER SubscriptionId
    ID da subscription de destino.

.PARAMETER ResourceGroupName
    Nome do novo Resource Group a ser criado.

.PARAMETER Location
    Região onde o Resource Group será criado. Padrão: brazilsouth

.PARAMETER TemplatePath
    Caminho do arquivo resource_template.json. Padrão: .\azure-migration\resource_template.json

.PARAMETER SkipLogin
    Se especificado, pula o login (útil se já estiver autenticado).

.EXAMPLE
    .\Import-AzureResourceGroup.ps1 -TenantId "xxx" -SubscriptionId "yyy" -ResourceGroupName "my-new-rg"

.EXAMPLE
    .\Import-AzureResourceGroup.ps1 -TenantId "xxx" -SubscriptionId "yyy" -ResourceGroupName "my-new-rg" -Location "eastus" -SkipLogin

.NOTES
    Author: Pedro
    Requires: Azure CLI installed
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "ID do tenant Azure de destino")]
    [string]$TenantId,

    [Parameter(Mandatory = $false, HelpMessage = "ID da subscription de destino")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = "Nome do novo Resource Group")]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Região do Resource Group")]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Caminho do arquivo de template")]
    [string]$TemplatePath,

    [Parameter(Mandatory = $false, HelpMessage = "Pular login se já autenticado")]
    [switch]$SkipLogin
)

# === VERIFICAR EXECUTION POLICY ===
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
$effectivePolicy = Get-ExecutionPolicy

if ($effectivePolicy -eq "Restricted") {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "⚠️  EXECUTION POLICY BLOQUEADA" -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "A política de execução atual não permite rodar scripts." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Opções para resolver:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Opção 1 - Executar apenas este script (recomendado):" -ForegroundColor White
    Write-Host "   powershell -ExecutionPolicy Bypass -File .\Import-AzureResourceGroup.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   Opção 2 - Alterar política para o usuário atual:" -ForegroundColor White
    Write-Host "   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# === CABEÇALHO ===
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "☁️  AZURE RESOURCE GROUP IMPORTER" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# === SOLICITAR PARÂMETROS FALTANTES ===
if ([string]::IsNullOrWhiteSpace($TemplatePath)) {
    Write-Host "📄 Caminho do template:" -ForegroundColor Yellow -NoNewline
    Write-Host " (arquivo resource_template.json exportado)" -ForegroundColor DarkGray
    Write-Host "   Pressione Enter para usar o padrão: .\azure-migration\resource_template.json" -ForegroundColor DarkGray
    $inputPath = Read-Host "   Digite o caminho"
    
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        $TemplatePath = ".\azure-migration\resource_template.json"
    } else {
        $TemplatePath = $inputPath
    }
    Write-Host ""
}

# === VERIFICAR SE TEMPLATE EXISTE ===
if (!(Test-Path $TemplatePath)) {
    Write-Host "❌ Arquivo de template não encontrado: $TemplatePath" -ForegroundColor Red
    Write-Host "💡 Execute primeiro o script Export-AzureResourceGroup.ps1" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ Template encontrado: $TemplatePath" -ForegroundColor Green
    Write-Host ""
}

if ([string]::IsNullOrWhiteSpace($TenantId)) {
    Write-Host "🔑 Tenant ID de destino:" -ForegroundColor Yellow -NoNewline
    Write-Host " (encontre em: Azure Portal > Azure Active Directory > Overview)" -ForegroundColor DarkGray
    $TenantId = Read-Host "   Digite o Tenant ID"
    
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        Write-Host "❌ Tenant ID é obrigatório." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
    Write-Host "🎫 Subscription ID de destino:" -ForegroundColor Yellow -NoNewline
    Write-Host " (encontre em: Azure Portal > Subscriptions)" -ForegroundColor DarkGray
    $SubscriptionId = Read-Host "   Digite o Subscription ID"
    
    if ([string]::IsNullOrWhiteSpace($SubscriptionId)) {
        Write-Host "❌ Subscription ID é obrigatório." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
    Write-Host "📦 Nome do novo Resource Group:" -ForegroundColor Yellow -NoNewline
    Write-Host " (nome que será criado no destino)" -ForegroundColor DarkGray
    $ResourceGroupName = Read-Host "   Digite o nome do Resource Group"
    
    if ([string]::IsNullOrWhiteSpace($ResourceGroupName)) {
        Write-Host "❌ Resource Group Name é obrigatório." -ForegroundColor Red
        exit 1
    }
    Write-Host ""
}

if ([string]::IsNullOrWhiteSpace($Location)) {
    Write-Host "🌎 Região do Resource Group:" -ForegroundColor Yellow -NoNewline
    Write-Host " (ex: brazilsouth, eastus, westeurope)" -ForegroundColor DarkGray
    Write-Host "   Pressione Enter para usar o padrão: brazilsouth" -ForegroundColor DarkGray
    $inputLocation = Read-Host "   Digite a região"
    
    if ([string]::IsNullOrWhiteSpace($inputLocation)) {
        $Location = "brazilsouth"
    } else {
        $Location = $inputLocation
    }
    Write-Host ""
}

# === EXIBIR CONFIGURAÇÃO ===
Write-Host "📋 Configuração:" -ForegroundColor Cyan
Write-Host "   Tenant ID:      $TenantId" -ForegroundColor White
Write-Host "   Subscription:   $SubscriptionId" -ForegroundColor White
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "   Região:         $Location" -ForegroundColor White
Write-Host "   Template:       $TemplatePath" -ForegroundColor White
Write-Host "   Skip Login:     $SkipLogin" -ForegroundColor White
Write-Host ""

# === CONFIRMAÇÃO ===
Write-Host "⚠️  ATENÇÃO:" -ForegroundColor Yellow
Write-Host "   Esta operação irá criar recursos no Azure e pode gerar custos." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "   Deseja continuar? (S/N)"

if ($confirm -notmatch "^[Ss]$") {
    Write-Host ""
    Write-Host "❌ Operação cancelada pelo usuário." -ForegroundColor Red
    exit 0
}
Write-Host ""

# === VALIDAR AZURE CLI ===
Write-Host "🔍 Verificando Azure CLI..." -ForegroundColor Cyan

$azVersion = az version 2>$null | ConvertFrom-Json
if (-not $azVersion) {
    Write-Host "❌ Azure CLI não está instalado ou não está no PATH." -ForegroundColor Red
    Write-Host "💡 Instale via: winget install Microsoft.AzureCLI" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ Azure CLI versão: $($azVersion.'azure-cli')" -ForegroundColor Green
}

# === LOGIN NO TENANT ===
if (-not $SkipLogin) {
    Write-Host "🔐 Fazendo login no tenant de destino: $TenantId" -ForegroundColor Cyan
    
    try {
        az logout 2>$null
        az account clear 2>$null
        az login --tenant $TenantId
        
        if ($LASTEXITCODE -ne 0) {
            throw "Falha no login"
        }
        
        Write-Host "✅ Login realizado com sucesso!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erro ao fazer login: $_" -ForegroundColor Red
        Write-Host "💡 Verifique se o Tenant ID está correto" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "⏭️  Pulando login (usando sessão existente)" -ForegroundColor Yellow
}

# === SELECIONAR SUBSCRIPTION ===
Write-Host "🎯 Selecionando subscription: $SubscriptionId" -ForegroundColor Cyan

try {
    az account set --subscription $SubscriptionId
    
    if ($LASTEXITCODE -ne 0) {
        throw "Falha ao selecionar subscription"
    }
    
    Write-Host "✅ Subscription selecionada com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro ao selecionar subscription: $_" -ForegroundColor Red
    Write-Host "💡 Verifique se o Subscription ID está correto e se você tem acesso" -ForegroundColor Yellow
    exit 1
}

# === VERIFICAR SE RESOURCE GROUP JÁ EXISTE ===
Write-Host "🔍 Verificando se Resource Group já existe..." -ForegroundColor Cyan

$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "true") {
    Write-Host "⚠️  Resource Group '$ResourceGroupName' já existe." -ForegroundColor Yellow
    $overwrite = Read-Host "   Deseja fazer deploy no Resource Group existente? (S/N)"
    
    if ($overwrite -notmatch "^[Ss]$") {
        Write-Host ""
        Write-Host "❌ Operação cancelada pelo usuário." -ForegroundColor Red
        exit 0
    }
    Write-Host ""
} else {
    # === CRIAR RESOURCE GROUP ===
    Write-Host "📦 Criando Resource Group: $ResourceGroupName" -ForegroundColor Cyan
    
    try {
        az group create --name $ResourceGroupName --location $Location --output none
        
        if ($LASTEXITCODE -ne 0) {
            throw "Falha ao criar Resource Group"
        }
        
        Write-Host "✅ Resource Group criado com sucesso!" -ForegroundColor Green
    } catch {
        Write-Host "❌ Erro ao criar Resource Group: $_" -ForegroundColor Red
        exit 1
    }
}

# === FAZER DEPLOY DO TEMPLATE ===
Write-Host "🚀 Iniciando deploy dos recursos..." -ForegroundColor Cyan
Write-Host "   Isso pode levar alguns minutos..." -ForegroundColor DarkGray
Write-Host ""

$deploymentName = "deployment-" + (Get-Date -Format "yyyyMMdd-HHmmss")

try {
    $deployResult = az deployment group create `
        --name $deploymentName `
        --resource-group $ResourceGroupName `
        --template-file $TemplatePath `
        --output json 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erro durante o deploy:" -ForegroundColor Red
        Write-Host $deployResult -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 Dicas:" -ForegroundColor Yellow
        Write-Host "   - Verifique se os nomes dos recursos já existem (devem ser únicos)" -ForegroundColor Yellow
        Write-Host "   - Alguns recursos como Azure OpenAI podem ter restrições regionais" -ForegroundColor Yellow
        Write-Host "   - Verifique as cotas da subscription" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "✅ Deploy concluído com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "❌ Erro ao fazer deploy: $_" -ForegroundColor Red
    exit 1
}

# === LISTAR RECURSOS CRIADOS ===
Write-Host ""
Write-Host "📋 Recursos criados no Resource Group:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray
az resource list --resource-group $ResourceGroupName --output table
Write-Host "────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

# === RESUMO ===
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "✅ IMPORTAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "📦 Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "🌎 Região:         $Location" -ForegroundColor White
Write-Host "🚀 Deployment:     $deploymentName" -ForegroundColor White
Write-Host ""
Write-Host "💡 Próximos passos:" -ForegroundColor Cyan
Write-Host "   - Verifique se todos os recursos estão funcionando" -ForegroundColor White
Write-Host "   - Configure HTTPS/certificados se necessário" -ForegroundColor White
Write-Host "   - Atualize connection strings e app settings" -ForegroundColor White
Write-Host "   - Configure Managed Identities e permissões" -ForegroundColor White
Write-Host ""

# === RETORNAR INFO ===
$result = @{
    ResourceGroupName = $ResourceGroupName
    Location          = $Location
    DeploymentName    = $deploymentName
    TenantId          = $TenantId
    SubscriptionId    = $SubscriptionId
}

return $result