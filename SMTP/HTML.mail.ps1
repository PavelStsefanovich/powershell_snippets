$status = "Failure"
$env:Node = "xyi"
$release = "6.1.8.88"
$buid = 1785

$htmlScript = @("<html><head><title>Fortify Result</title>")
$htmlScript += ,("<style type='text/css'>")
$htmlScript += ,("table.imagetable {")
$htmlScript += ,("font-family: verdana,arial,sans-serif;")
$htmlScript += ,("	font-size:11px;")
$htmlScript += ,("color:#333333;")
$htmlScript += ,("border-width: 1px;")
$htmlScript += ,("border-color: #999999;")
$htmlScript += ,("border-collapse: collapse;")
$htmlScript += ,("}")
$htmlScript += ,("table.imagetable th {")
$htmlScript += ,("background:#b5cfd2 url('cell-blue.jpg');")
$htmlScript += ,("	border-width: 1px;")
$htmlScript += ,("	padding: 8px;")
$htmlScript += ,("	border-style: solid;")
$htmlScript += ,("	border-color: #999999;")
$htmlScript += ,("}")
$htmlScript += ,("table.imagetable td {")
$htmlScript += ,("	background:#dcddc0 url('cell-grey.jpg');")
$htmlScript += ,("	border-width: 1px;")
$htmlScript += ,("	padding: 8px;")
$htmlScript += ,("	border-style: solid;")
$htmlScript += ,("	border-color: #999999;")
$htmlScript += ,("}")
$htmlScript += ,("</style></head>")
$htmlScript += ,("<table class='imagetable'><tr><th>Node</th><th>Deployment Status</th><th>Release</th><th>Build</th></tr>")
$htmlScript += ,("<tr><td>$env:Node</td><td>$status</td><td>$release</td><td>$buid</td></tr></table></html>")

$htmlScript | Out-File email.txt
