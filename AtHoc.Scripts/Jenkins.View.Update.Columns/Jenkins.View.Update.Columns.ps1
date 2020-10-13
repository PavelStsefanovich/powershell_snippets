[cmdletbinding()]
param (
    [string]$ViewName,
    [string]$SampleView = "BR"
)


$JENKINS_HOME = "C:\Program Files (x86)\Jenkins\"
$JENKINS_CONFIGFILE = $JENKINS_HOME + "config.xml"
$configFileBackup = $JENKINS_HOME + "config-bkp.xml"

# display parameters
write "ViewName`t`t$ViewName"
write "SampleView`t`t$SampleView"
write "JENKINS_CONFIGFILE`t$JENKINS_CONFIGFILE"

# load and validate existing config
Write-Verbose " > Loading config file ..."
$config = (Select-Xml $JENKINS_CONFIGFILE -XPath '/').Node
if (!($config.hudson.views.listView | ?{$_.name -eq $ViewName})) {
    throw "!!ERROR: View <$ViewName> can not be found"
}
if (!($config.hudson.views.listView | ?{$_.name -eq $SampleView})) {
    throw "!!ERROR: View <$SampleView> can not be found"
}

# backup config file
Write-Verbose " > Backin up Jenkins config file ..."
rm $configFileBackup -Force -ErrorAction SilentlyContinue
cp $JENKINS_CONFIGFILE $configFileBackup -Force -ErrorAction Stop

# update columns information
Write-Verbose " > Updating config ..."
$sampleColumns = ($config.hudson.views.listView | ?{$_.name -eq $SampleView}).columns.clone()
$targetViewConfig = ($config.hudson.views.listView | ?{$_.name -eq $ViewName})
($config.hudson.views.listView | ?{$_.name -eq $ViewName}).ReplaceChild($sampleColumns,$targetViewConfig.columns)

# saving config
try {
    $config.Save($JENKINS_CONFIGFILE)
}
catch {
    throw "!!ERROR: $_"
}
