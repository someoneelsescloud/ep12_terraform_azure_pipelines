# Terraform - Download & Configure on Windows
# https://kpatnayakuni.com/2019/12/05/terraform-download-configure-on-windows-using-powershell/

# Updated to use in Azure Pipelines

param (
    
    [parameter(Mandatory = $false)]
    [string]$version = 'latest',
    [parameter(Mandatory = $false)]
    [string]$outputDir = '.\'
)

Write-Output "Checking for any Terraform executables and deleting before downloading..."
if (Test-Path -Path "$($outputDir)terraform.exe") {
    Remove-Item "$($outputDir)terraform.exe"
}

# Download the Terraform exe in zip format
if ($version -eq "latest") {
    Write-Output "Querying Terraform website to obtain download links for $version Terraform.."
    $Url = "https://www.terraform.io/downloads.html"
    $Web = Invoke-WebRequest -Uri $Url
    $FileInfo = $Web.Links | Where-Object href -match "windows_amd64"
    $DownloadLink = $FileInfo.href
}
else {
    Write-Output "Querying Terraform website to obtain download links for Terraform $version.."
    $Url = "https://releases.hashicorp.com"
    $DownloadLink = "https://releases.hashicorp.com/terraform/$version/"
    $Web = Invoke-WebRequest -Uri $DownloadLink
    $FileInfo  = $Web.Links | Where-Object href -match "windows_amd64"
    $DownloadLink = "$Url" + "$($FileInfo.href)"
}

Write-Output "Downloading the Terraform $version of the executable.."
$FileName = Split-Path -Path $DownloadLink -Leaf
$DownloadFile = [string]::Concat( $outputDir, $FileName )
Invoke-RestMethod -Method Get -Uri $DownloadLink -OutFile $DownloadFile
 
Write-Output "Extract & delete the zip file to $outputDir.."
Expand-Archive -Path $DownloadFile -DestinationPath $outputDir -Force
Remove-Item -Path $DownloadFile -Force