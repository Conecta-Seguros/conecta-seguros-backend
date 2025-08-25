param (
    [Parameter(Mandatory=$true)]
    [string]$EntityName
)

$basePath = "$EntityName"

$folders = @(
    "application/command",
    "application/mapper",
    "application/service",
    "domain/criteria",
    "domain/exceptions",
    "domain/model/enums",
    "domain/model/valueobject",
    "domain/port/input",
    "domain/port/output",
    "infrastructure/config",
    "infrastructure/input/dto",
    "infrastructure/input/rest",
    "infrastructure/output/adapter",
    "infrastructure/output/entity",
    "infrastructure/output/mapper",
    "infrastructure/output/repository"
)

foreach ($folder in $folders) {
    $path = Join-Path -Path $basePath -ChildPath $folder
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

Write-Host "Estructura creada exitosamente bajo la carpeta '$EntityName'"