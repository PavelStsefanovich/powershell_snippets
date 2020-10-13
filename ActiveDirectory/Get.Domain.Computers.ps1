$DirSearcher = New-Object System.DirectoryServices.DirectorySearcher([adsi]'')
$DirSearcher.Filter = '(objectClass=Computer)'
#$DirSearcher.FindAll().GetEnumerator() | ForEach-Object { $_.Properties.name }
#$DirSearcher.FindAll().GetEnumerator() | ForEach-Object { $_.Properties.name } | sort
$computers = $DirSearcher.FindAll().GetEnumerator() | ForEach-Object { $_.Properties.name } | sort

foreach ($comp in $computers) {
    $comp
    #Invoke-Command -ComputerName $comp -ScriptBlock {
    #    ls c:\br\* -include *.pfx,*crt | rm -Force -ErrorAction SilentlyContinue
    #} -ErrorAction Continue
}