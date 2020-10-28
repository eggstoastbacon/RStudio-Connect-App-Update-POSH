#RStudio Connect Application Update POSH
#EggsToastBacon 10/28/2020

#csv file should contain 3 columns; 
#1. host: url of the RStudio connect server "https://connect.company.com", 
#2. guid: guid of the existing application to update
#3. key: api key of the server to authenticate

#Use the config file to specify, config file stays in the same directory as the script.
#1. CSV File location
#2. CURL location (use the latest CURL binaries)
#3. Location of the application update tar.gz file
#4. App name


$config = get-content .\config.txt
$nodes = Invoke-Expression $config[1]
$curl_loc = Invoke-Expression $config[3]
$package_loc = Invoke-Expression $config[5]
$appname = Invoke-Expression $config[7]
cls
$go = read-host "This will update app: $appname with bundle: $package_loc, press ENTER to continue"

clear-variable errors -ErrorAction SilentlyContinue
foreach($node in $nodes){
$hostname = $node.host
$guid = $node.guid
$key = $node.key

write-host "Deploying to $hostname" -ForegroundColor Cyan

$bundle = cmd.exe /C $curl_loc --silent --show-error -L --max-redirs 10 -X POST -H "Authorization: Key $key" --data-binary $package_loc "$hostname/__api__/v1/experimental/content/$guid/upload"
#$data = cmd.exe /C c:\curl\bin\curl.exe --show-error -L --max-redirs 10 -X POST -H "Authorization: Key $key" --data-binary '@"c:\curl\bundle-564.tar.gz"' "http://lab01.cdph.ca.gov/__api__/v1/experimental/content/79d7bc41-39ad-47fa-a989-fca23489cbf1/upload"

$bundle = $bundle | convertFrom-JSON
$id = $bundle.bundle_id

write-host "Bundle ID $id" -ForegroundColor Cyan

$json = @"
{"BUNDLE_ID":"$id"}
"@

$json = $json| ConvertTo-Json

$task = cmd.exe /C $curl_loc --silent --max-redirs 10 -X POST -H "Authorization: Key $key" -H "Accept: application/json" -d $json -L "$hostname/__api__/v1/experimental/content/$guid/deploy"

$task = $task | ConvertFrom-JSON
$task = $task.task_id

write-host "Task $task" -ForegroundColor Cyan
$x = 0
do{$result = cmd.exe /C $curl_loc -k --silent --show-error -L --max-redirs 0 -H "Authorization: Key $key" ("$hostname/__api__/v1/experimental/tasks/" + $task + "?wait=1")
$result = $result | convertFrom-JSON
start-sleep 5
$x = $x + 5
write-host "$x seconds elapsed deploying on $hostname" -ForegroundColor Yellow

if ($x -gt 300){
$errors += "$hostname : Didn't get the finished result after 5 minutes : $result"
break
}}
while($result.finished -notlike "*True*")
if ($result.error){
$errors += "$hostname : Error Detected  : $result"
}

write-host "Done on $hostname.."
}

if($errors){write-host "Errors Detected"
$errors
}
$finished = read-host "Finished.. press any key to close."
