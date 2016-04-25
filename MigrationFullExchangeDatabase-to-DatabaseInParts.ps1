#Change these variables to fit your environment and choices
$SourceDatabase='DB1'
$TargetDatabase='DB2'
$NumberOfMailboxesToBatch=5
$NotificationEmail='notification@NotificationEmailDomain.com'

#Leave the rest of this alone
$TestSourceDatabase=Get-MailboxDatabase -Identity $SourceDatabase -ErrorAction silentlycontinue
$TestTargetDatabase=Get-MailboxDatabase -Identity $TargetDatabase -ErrorAction SilentlyContinue

if($TestSourceDatabase -eq $null)
{
    $SourceDatabaseError="Source Database $SourceDatabase could not be found or could not be accessed"
    write-error $SourceDatabaseError
    break
}

if($TestTargetDatabase -eq $null)
{
    $TargetDatabaseError="Target Database $TargetDatabase could not be found or could not be accessed"
    write-error $TargetDatabaseError
    break
}

$SourceDatabaseName=$SourceDatabase -replace '[^a-zA-Z0-9]',''
$TargetDatabaseName=$TargetDatabase -replace '[^a-zA-Z0-9]',''

$MailboxesToMove=get-mailbox -database $SourceDatabase

$ActiveNumberOfMailboxesInBatch=1
$CurrentBatchNumber=1
$CurrentMailboxCount=1
$TotalNumberOfMailboxes=$MailboxesToMove.count
$CurrentMailboxSet=@()

$CSVFileLocation='C:\temp\DBtoDBMigration'
if(!(Test-Path $CSVFileLocation))
{
    New-Item -Path $CSVFileLocation -ItemType Directory
}

foreach($Mailbox in $MailboxesToMove)
{

    $WorkingName="$SourceDatabaseName`_to`_$TargetDatabaseName`_pre_$CurrentBatchNumber"
    $FinalName="$SourceDatabaseName`_to`_$TargetDatabaseName`_$CurrentBatchNumber"

    $CSVFileFullPath="$CSVFileLocation\$FinalName.csv"

    try{$CurrentMailboxSet=$(get-variable $WorkingName -ErrorAction Stop).Value}
    catch{new-variable $WorkingName -Value @()}

    $CurrentMailboxSet+=$Mailbox.PrimarySmtpAddress
    set-variable $WorkingName -Value $CurrentMailboxSet

    if(($ActiveNumberOfMailboxesInBatch -eq $NumberOfMailboxesToBatch) -or ($CurrentMailboxCount -eq $TotalNumberOfMailboxes))
    {

        New-Variable $FinalName -value $($(get-variable $WorkingName) | Select-Object -ExpandProperty value | Select-Object @{label='EmailAddress';expression={$_}})
        $(get-variable $FinalName).Value | Export-Csv -NoTypeInformation -Path $CSVFileFullPath
        
        if($NotificationEmail -match "[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?")
        {
            New-MigrationBatch -Local -Name $FinalName -CSVData ([System.IO.File]::ReadAllBytes("$CSVFileFullPath")) -TargetDatabases $TargetDatabase -AutoComplete -AutoStart -BadItemLimit 99999 -NotificationEmails $NotificationEmail
        }
        else
        {
            New-MigrationBatch -Local -Name $FinalName -CSVData ([System.IO.File]::ReadAllBytes("$CSVFileFullPath")) -TargetDatabases $TargetDatabase -AutoComplete -AutoStart -BadItemLimit 99999
        }
        
        Remove-Item -Path $CSVFileFullPath
        
        $ActiveNumberOfMailboxesInBatch=0
        $CurrentBatchNumber++
        $CurrentMailboxSet=@()

    }

    $ActiveNumberOfMailboxesInBatch++
    $CurrentMailboxCount++

}