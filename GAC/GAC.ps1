[System.Reflection.Assembly]::Load("System.EnterpriseServices, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")
$publish = New-Object System.EnterpriseServices.Internal.Publish
$publish.GacInstall("C:\root\CHF1(6.1.8.87CP1)\AtHocENS\ServerObjects\DOTNET\AtHoc.Scheduling.dll")
