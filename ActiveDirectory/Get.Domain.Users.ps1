$DirSearcher = New-Object System.DirectoryServices.DirectorySearcher([adsi]'')
$DirSearcher.Filter = '(objectClass=User)'
#$DirSearcher.FindAll().GetEnumerator() | ForEach-Object { $_.Properties.name }
#$DirSearcher.FindAll().GetEnumerator() | ForEach-Object { $_.Properties.name } | sort
$users = $DirSearcher.FindAll().GetEnumerator() | sort -Property name

$users | %{$_.Properties.name} | sort
<#
foreach ($user in $users) {
    $user.Properties.userprincipalname
    #Invoke-Command -ComputerName $comp -ScriptBlock {
    #    ls c:\br\* -include *.pfx,*crt | rm -Force -ErrorAction SilentlyContinue
    #} -ErrorAction Continue
}


cn
countrycode
co
l
primarygroupid
whenchanged
c
rimcostcentre
lockouttime
rimbuildingname
rimfloorid
distinguishedname
st
protocolsettings
physicaldeliveryofficename
postalcode
objectsid
displayname
msexchumdtmfmap
accountexpires
userprincipalname
givenname
codepage
objectcategory
scriptpath
description
usnchanged
instancetype
name
rimguid
pwdlastset
objectclass
badpwdcount
samaccounttype
employeeid
usncreated
sn
company
msexchalobjectversion
rimobjtype
objectguid
whencreated
adspath
useraccountcontrol
#>