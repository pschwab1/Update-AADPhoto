<#
    .SYNOPSIS
        This script compares the user AD photo from Huisman on-premises environment with the Exchange Online environment.
        Azure AD only migrates the photo
        Huisman uses the AD Photo Edit software to add user pictures into their accounts, and once the user is migrated to Azure AD, it doesn't update this attribute any
    .Notes
        Author: Paulo Schwab
        Date: 18-Dec-2020

#>
[CmdletBinding()]
param
(
    [Parameter(Mandatory=$false,Position=0)]
    [string]$DomainUser,

    [Parameter(Mandatory=$false,Position=1)]
    [string]$SearchBase = (Get-ADDomain).DistinguishedName

)

begin {

    Function LogWrite
    {
        Param ([string]$LogString)
        $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
        #$LogString | Out-File $Logfile -Append
        $LogMessage = "$stamp $LogString"
        Add-content $Logfile -value $LogMessage
    }

    Start-Transcript -Path $PSScriptRoot\Logs\Transcript-$dateTime.txt -Append -Confirm:$false -Force
    
    try{
        # Connect to Exchange Online (ExchangeOnline Module needed)
        if ((!(Get-PSSession | Where-Object {$_.computername -eq "outlook.office365.com"})) -and ($env:USERNAME -eq "svc-ad-mgmt"))
        {
            Connect-ExchangeOnline -AppId "yourAppIDHere" -Organization "OrganizationName" -CertificateFilePath 'c:\EXOCertificate.pfx'
        } else {
            Connect-ExchangeOnline
        }
    } catch{
        LogWrite $_
    }


}

process {

    Write-Output "Collecting photos from OnPrem and O365 environments..."
    # Collect user photos from On-Prem and O365 environments
    if ($DomainUser){
        $users = Get-ADUser $DomainUser -Properties SamAccountName,thumbnailPhoto
    } else {
        $users = Get-ADUser -SearchBase $SearchBase -filter {thumbnailPhoto -ne "NULL"} -Properties SamAccountName,thumbnailPhoto | Select-Object SamAccountName, thumbnailPhoto
    }

    foreach ($user in $users) {
        try{
            $user.thumbnailPhoto | Set-Content $PSSCriptRoot\OnPremPhotos\$($user.SamAccountName).jpg -Encoding Byte -Confirm:$False -Force
            (Get-UserPhoto $user.SamAccountName).picturedata | Set-Content $PSSCriptRoot\O365Photos\$($user.SamAccountName).jpg -Encoding Byte -Confirm:$False -Force
        } catch {
            Write-Output $Error[0].Exception
            LogWrite $_
        }
    }

    Write-Output "Comparing files..."
    # Compares the File Hash with the OnPrem and O365. If doesn't match, it overrides the O365 photo with the OnPrem photo
    foreach ($user in $users) {
        $OnPremPhotos = Get-FileHash $PSSCriptRoot\OnPremPhotos\$($user.samaccountname).jpg
        $O365Photos = Get-FileHash $PSSCriptRoot\O365Photos\$($user.samaccountname).jpg

        if ($OnPremPhotos.Hash -ne $O365Photos.Hash) {
            try {
                Write-Output "Updating $($user.samaccountname) picture..."
                Set-UserPhoto -Identity $($user.samaccountname) -PictureData ([System.IO.File]::ReadAllBytes("$PSSCriptRoot\OnPremPhotos\$($user.samaccountname).jpg")) -Confirm:$False
            }
            catch {
                Write-Output $Error[0].Exception
                LogWrite $_
            }
        }
    }
}

end {
    Disconnect-ExchangeOnline -Confirm:$False
    Stop-Transcript
}