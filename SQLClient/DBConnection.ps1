$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=172.16.10.38;Initial Catalog=ngdeliveryaccount;User Id=ngad;Password=@THOC123;"
$SqlConnection.Open()
$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
$SqlCmd.CommandText = "select AppObjectId from dbo.Access where AccessId = 6"
$SqlCmd.Connection = $SqlConnection
$result= $SqlCmd.ExecuteScalar()
$SqlConnection.Close()
Write-output "result: " $result
pause
#Provider=SQLOLEDB.1;Server=PAVELSANDBOX;Initial Catalog=ngaddata;User Id=ngad;Password=@THOC123;