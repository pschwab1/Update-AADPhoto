
$user = Get-aduser pschwab -Properties thumbnailphoto

# Connect to Exchange Online (ExchangeOnline Module needed)
if ((!(Get-PSSession | Where-Object {$_.computername -eq "outlook.office365.com"})) -and ($env:USERNAME -eq "svc-ad-mgmt"))
{
    $password = Get-Content "$PSScriptRoot\EncryptedPass.txt" | ConvertTo-SecureString
    Connect-ExchangeOnline -AppId "580c25e4-1602-45c1-88af-1bc4eda557dc" -Organization "huismancloud.onmicrosoft.com" -CertificateFilePath 'c:\HuismanExchangeOnline.pfx' -CertificatePassword $password
} else {
    #Connect-ExchangeOnline
}



function Set-UpdateThumbnailPhoto {

    <#
        .Description
        This function checks the modified date of the thumbnailphoto in the OnPrem AD and replaces it in Exchange Online
        The variable $days is used to select how many days prior today the script needs to search. Use negative integers.
    #>

    [CmdletBinding()]
    Param (
    $User,
    [int]$Days = -1
    )

    $photoData = Get-ADReplicationAttributeMetadata -Object $User.distinguishedName -server "nl-sch01-dc02" | Select-Object `
          AttributeName, `
          AttributeValue, `
          LastOriginatingChangeTime, `
          LastOriginatingChangeDirectoryServerInvocationId | where-object {$_.AttributeName -eq "thumbnailPhoto"}

    if ($photoData.LastOriginatingChangeTime -eq (Get-Date).AddDays($days)){
        Write-Output "Trying to update picture from user: $($user.samaccountname)"
        Set-EXOPhoto -User $user
    }
}

function Set-EXOPhoto {
    [CmdletBinding()]
    Param ($User)
    try {
        if (!(Test-Path $PSSCriptRoot\OnPremPhotos)){
            New-Item -Path $PSSCriptRoot\OnPremPhotos -Type Directory
        }

        $User.thumbnailPhoto | Set-Content $PSSCriptRoot\OnPremPhotos\$($User.SamAccountName).jpg -Encoding Byte -Confirm:$False -Force
        Set-UserPhoto -Identity $($User.samaccountname) -PictureData ([System.IO.File]::ReadAllBytes("$PSSCriptRoot\OnPremPhotos\$($User.samaccountname).jpg")) -Confirm:$False
    }
    catch {
        Write-Error $_
    }


}



Set-UpdateThumbnailPhoto -User $user

