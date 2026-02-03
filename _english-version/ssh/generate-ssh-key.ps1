param(
    [string]$Email,
    [string]$Name
)

# Function to verify and handle existing keys
function Resolve-ExistingKey {
    param(
        [string]$KeyName,
        [string]$SshDirectory
    )
    
    # Remove "id_" prefix if user typed it
    if ($KeyName.StartsWith("id_")) {
        $KeyName = $KeyName.Substring(3)
    }
    
    $KeyPath = Join-Path $SshDirectory "id_$KeyName"
    
    # If key doesn't exist, return the name
    if (-not (Test-Path $KeyPath)) {
        return $KeyName
    }
    
    # Key exists - display information
    Write-Host "`n⚠️  The key '$KeyPath' already exists!" -ForegroundColor Yellow
    
    # Display existing public key content
    $PublicKeyPath = "$KeyPath.pub"
    if (Test-Path $PublicKeyPath) {
        Write-Host "`n📄 Existing public key content:" -ForegroundColor Cyan
        Get-Content $PublicKeyPath | Write-Host -ForegroundColor White
    }
    
    Write-Host "`n🤔 What would you like to do?" -ForegroundColor Gray
    Write-Host "  ↩️ ENTER - Overwrite existing file" -ForegroundColor Gray
    Write-Host "  ✏️ Type a new name - Generate with another name" -ForegroundColor Gray
    Write-Host "  ⛔ Type 'exit' or press Ctrl+C to cancel" -ForegroundColor Gray
    
    # Capture input
    Write-Host "`n👉 Type: "-NoNewline  -ForegroundColor Gray
    $Response = $Host.UI.ReadLine()
    
    if ([string]::IsNullOrWhiteSpace($Response)) {
        # ENTER pressed - overwrite
        Write-Host "`n🔄 Overwriting existing file..." -ForegroundColor Yellow
        return $KeyName
    }
    elseif ($Response.ToLower() -eq "exit" `
            -or $Response.ToLower() -eq "e" `
            -or $Response.ToLower() -eq "quit") {
        # "exit" typed
        Write-Host "`n❌ Operation cancelled." -ForegroundColor Red
        exit
    }
    else {
        # New name typed - verify recursively
        return Resolve-ExistingKey -KeyName $Response -SshDirectory $SshDirectory
    }
}

# If email was not provided, request it
if ([string]::IsNullOrWhiteSpace($Email)) {
    $Email = Read-Host "📧 Enter email"
}

# Extract email prefix
$EmailPrefix = $Email.Split('@')[0]

# If name was not provided, request it
if ([string]::IsNullOrWhiteSpace($Name)) {
    Write-Host "🔑 Enter key name (leave blank to use " -NoNewline  -ForegroundColor Gray
    Write-Host $EmailPrefix -ForegroundColor Yellow -NoNewline
    Write-Host "): " -NoNewline  -ForegroundColor Gray
    $Name = Read-Host
}

# If name is blank, use email prefix
if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = $EmailPrefix
    Write-Host "✨ Using '" -ForegroundColor Gray -NoNewline
	Write-Host $EmailPrefix -ForegroundColor Yellow -NoNewline
	Write-Host "' as key name (extracted from email)"  -ForegroundColor Gray
}

# Remove "id_" prefix if user typed it
if ($Name.StartsWith("id_")) {
    $Name = $Name.Substring(3)
    Write-Host "📌 Removed duplicate 'id_' prefix. Using: $Name" -ForegroundColor Yellow
}

# Build complete file path (always in ~/.ssh)
$SshDir = Join-Path $env:USERPROFILE ".ssh"
if (-not (Test-Path $SshDir)) {
    New-Item -ItemType Directory -Path $SshDir -Force | Out-Null
    Write-Host "📁 .ssh directory created at: $SshDir" -ForegroundColor Green
}

# Verify and resolve key name (handling duplicates)
$Name = Resolve-ExistingKey -KeyName $Name -SshDirectory $SshDir
$KeyPath = Join-Path $SshDir "id_$Name"

Write-Host "`n🔐 Generating SSH key id_$Name" -ForegroundColor Cyan
Write-Host "📝 ssh-keygen -t ed25519 -C `"$Email`" -f `"$KeyPath`" -N `"`"`n" -ForegroundColor White

# Execute ssh-keygen (with empty passphrase and overwrite without asking)
echo y | ssh-keygen -t ed25519 -C $Email -f $KeyPath -N ""

# Verify if key was generated successfully
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=================================" -ForegroundColor Green
    Write-Host "✅ SSH key generated successfully!" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    
    # Display public key content
    $PublicKeyPath = "$KeyPath.pub"
    
    if (Test-Path $PublicKeyPath) {
        Write-Host "`n📋 Public key content (copy the text below):" -ForegroundColor Cyan
        Get-Content $PublicKeyPath | Write-Host -ForegroundColor White
    } else {
        Write-Host "`n⚠️  Warning: Could not find public key file at: $PublicKeyPath" -ForegroundColor Red
    }
} else {
    Write-Host "`n❌ Error generating SSH key!" -ForegroundColor Red
}
