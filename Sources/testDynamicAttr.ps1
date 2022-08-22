<#
    .SYNOPSIS
        This script compares the user AD photo from Huisman on-premises environment with the Exchange Online environment.
        Azure AD only migrates the photo
        Huisman uses the AD Photo Edit software to add user pictures into their accounts, and once the user is migrated to Azure AD, it doesn't update this attribute any
    .Notes
        Author: Paulo Schwab
        Date: 18-Dec-2020

        Changes:
        13-Jan-21 - Adjusted to run using the ExchangeOnline Module (Install-Module ExchangeOnlineManagement)
                    Adjusted to search specific OU and filter
#>

Function Update-AADPhoto {
    [CmdletBinding()]
    Param(
        [CmdletBinding()]
        [ValidateSet("Global","OrganizationalUnit","User")]
        [Parameter(Mandatory = $false,
            ValueFromPipeLine = $false,
            Position = 0,
            HelpMessage="Inform the Scope. Global, OU based or single user")]
    [string]$Scope = "Global",
    [ValidateSet("On-Premises","Cloud")]
    [Parameter(Mandatory = $false,
            ValueFromPipeLine = $false,
            Position = 1,
            HelpMessage="Inform the base environment")]
    [string]$SourcePhoto = "On-Premises")

    DynamicParam {
        if ($Scope -eq "OrganizationalUnit") {
            #create a new ParameterAttribute Object
            $attribute = New-Object System.Management.Automation.ParameterAttribute
            $attribute.Position = 2
            $attribute.Mandatory = $true
            $attribute.HelpMessage = "Inform the OU path"

            #create an attributecollection object for the attribute we just created.
            $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]

            #add our custom attribute
            $attributeCollection.Add($attribute)

            #add our paramater specifying the attribute collection
            $Param = New-Object System.Management.Automation.RuntimeDefinedParameter('SearchBase', [string], $attributeCollection)

            #expose the name of our parameter
            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('SearchBase', $Param)
            return $paramDictionary
       }

        if ($Scope -eq "User") {
            $attribute = New-Object System.Management.Automation.ParameterAttribute
            $attribute.Position = 2
            $attribute.Mandatory = $true
            $attribute.HelpMessage = "Inform the username"

            $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
            $attributeCollection.Add($attribute)

            $Param = New-Object System.Management.Automation.RuntimeDefinedParameter('UserName', [string], $attributeCollection)

            $paramDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
            $paramDictionary.Add('UserName', $Param)
            return $paramDictionary
        }
   }

   Begin {
        if ($Scope -eq "OrganizationalUnit" -and $null -eq $PSBoundParameters.SearchBase) {
            Write-Error "A valid OU path must be specifiec" -ErrorAction Stop
        }
        if ($Scope -eq "User" -and $null -eq $PSBoundParameters.UserName) {
            Write-Error "UserName must be specified" -ErrorAction Stop
        }
   }

   Process {

        switch ($Scope)
        {
            "Global" {$SearchBase = "OU=Users,OU=Huisman Global,DC=HSLE,DC=local"}
            "OrganizationalUnit" {
                $SearchBase = $PSBoundParameters.SearchBase
                $users = Get-ADUser -SearchBase $SearchBase -filter {thumbnailPhoto -ne "NULL"} -Properties SamAccountName,thumbnailPhoto | Select-Object SamAccountName, thumbnailPhoto
            }
            "User" {
                $users = Get-ADUser -Identity $PSBoundParameters.UserName -Properties SamAccountName,thumbnailPhoto | Select-Object SamAccountName, thumbnailPhoto
            }
        }

        switch ($SourcePhoto)
        {
            "On-Premises" {$source = "$PSSCriptRoot\OnPremPhotos"}
            "Cloud" {$source = "$PSSCriptRoot\O365Photos"}
        }



       Write-Host $users
       Write-Host $source
   }
}