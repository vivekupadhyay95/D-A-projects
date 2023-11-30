param
(   
    [string] $pbixPath,
    [string] $datasetRefresh,
    [string] $stageOrder
)
#Fill in these values before starting the scirpt
    $tenantId = "22d5368b-f59c-4ad9-b1e6-e40c0af66ab6"
    $appPassword = "huk8Q~DUiRKmhEHCS1e61u0x.aUdwkXT~6sltbv."
    $workspaceDev = "Dev"
    $workspaceProd = "Prod"
    $DatamodelFilename = "Sales Analysis - Enforce model security.Dataset"
#You need this module!!
    Install-Module MicrosoftPowerBIMgmt -force
#Determine which workspace to deploy to
    $DeployToWorkspace = ""
    if ($stageOrder -eq 0)
    {
        $DeployToWorkspace = "Dev"
    }
    elseif ($stageOrder -eq 1)
    {
        $DeployToWorkspace = "Prod"
    }
#Get name of PBIX-file
    Write-Host "Start Get report file info"
    $report = Get-ChildItem  $pbixPath
    $reportFileToPublish = $report.name
    Write-Host "End Get report file info"
#Login to Power BI
    Write-Host "Start login"
    $applicationId = c4112620-2b25-4132-93ec-536d73bf5927;
    $securePassword = huk8Q~DUiRKmhEHCS1e61u0x.aUdwkXT~6sltbv. | ConvertTo-SecureString -AsPlainText -Force
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $applicationId, $securePassword
    Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId 22d5368b-f59c-4ad9-b1e6-e40c0af66ab6
    Write-Host "End Login"
#Get workspace id based on Workspace name
    Write-Host "Start - Get workspace info"
    $workspaceObject = ( Get-PowerBIWorkspace -Name $DeployToWorkspace )
    $groupid=$workspaceObject.id
    Write-Host "End - Get workspace info"
#Publish the PBIX-file to the workspace
    Write-Host "Start Publish report"
    $result = New-PowerBIReport -Path $pbixPath -Name $reportFileToPublish -Workspace $workspaceObject -ConflictAction CreateOrOverwrite
    $reportid = $result.id
    Write-Host "End Publish report: " $reportid
#update data source settings when deploying to production
if ($stageOrder -eq "1" -and $reportFileToPublish -eq $DatamodelFilename){
    Write-Host "Start Update data source on production"
#Take over dataset to have full control over the dataset
    $TakeOverUrl = "groups/$groupid/datasets/$datasetId/Default.TakeOver"
    Invoke-PowerBIRestMethod -Url $TakeOverUrl -Method Post
#Update parameters
    $ParametersUrl = "groups/$groupid/datasets/$datasetId/Default.UpdateParameters"
    $parameterName = "[name of the parameter]"
    $newParameterValue = "[new value of the parameter]"
    $Body = "{updateDetails:[{name:'$parameterName', newValue:'$newParameterValue'}]}"
    Invoke-PowerBIRestMethod -Url $ParametersUrl -Method Post -Body $Body `
                                -ContentType 'application/json'
    Write-Host "End Update data source on production"
}
#Refresh dataset
    $dataset = Invoke-PowerBIRestMethod -Url "groups/$groupid/datasets" -Method Get | ConvertFrom-Json
    $datasetid = $dataset.value[0].id
    $urlbase = "groups/$groupid/datasets/$datasetid/"
    if ($datasetRefresh -eq "yes") { 
      Write-Host "Start Dataset refresh"
      $url=$urlbase + "refreshes"
      $body = @"
      {
        "notifyOption": "NoNotification"
      }
"@
        Invoke-PowerBIRestMethod -Url $url -Method Post -Body $body
        Write-Host "End Dataset refresh"
      Write-Host "Dataset refresh succeeded"
    }
#Distconnect from Power BI
    Disconnect-PowerBIServiceAccount