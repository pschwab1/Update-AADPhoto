<#
    This script renames the files received from Jack Ren
    files contained user Names (in Chinese) and their user IDs.
    A regex to extract the ID and file extension was made and renamed the files.

    .Author
    Pschwab - 02-Feb-2021
#>

Get-ChildItem | ForEach-Object {
    $item = $_.name
    $Pattern = '\d+|\.[^.]+$' #finds all numbers + file extension
    $results = $item | Select-String $Pattern -AllMatches
    $UserID = $results.Matches.Value[0]
    $fileExtension=$results.Matches.Value[1]
    Rename-Item $item -NewName $UserID$fileExtension

    Get-ADUser -Filter {extensionAttribute14 -eq $UserID} |  Set-ADUser -Replace @{thumbnailPhoto=([byte[]](Get-Content "C:\temp\$UserID$fileExtension" -Encoding byte))}
}
