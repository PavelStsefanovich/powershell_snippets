$chromeLocation = "C:\Program Files (x86)\Google\Chrome\Application"
$chromeAppsLocation = "~\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Chrome Apps"

rm "$chromeLocation\VisualElementsManifest.xml" -Force -ErrorAction SilentlyContinue

foreach ($file in (ls $chromeAppsLocation)) {
     $file.LastWriteTime = get-date
}