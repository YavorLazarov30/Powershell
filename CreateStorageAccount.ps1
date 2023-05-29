Connect-AzureAD

#Create the application: 

# Create a new HashMap
$properties = @{}

# Set the properties of the application object
$properties["DisplayName"] = "yavorlazarov1"
$properties["ReplyUrls"] = "http://localhost"

# Output the HashMap
$properties

#create the actual application object
$application = New-AzureADApplication -DisplayName $properties.DisplayName -ReplyUrls $properties.ReplyUrls


#Create the SPN from the Application: 
$appID = $application.AppId
$SPN = New-AzADServicePrincipal -ApplicationId $appID

#Assign the SPN with the Contributor RBAC role: 
$roleAssignment = New-AzRoleAssignment -ObjectId $SPN.Id -ResourceGroupName yavorlazarov1-vmss -RoleDefinitionName "Contributor"

#Create the Azure Storage account by using this identity: 
#1.Obtain the app secret: 
$AppSecret = Get-AzKeyVaultSecret -VaultName KV-secrets-yavor -Name AppSec
#2.Convert it to Secure string:
$applicationSecret = ConvertTo-SecureString -String $AppSecret.SecretValue -AsPlainText -Force
#3. Make app ID and secret credentials: 
$credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $AppSecret.SecretValue
#4. Disconnect from the normal account:
Disconnect-AzAccount
#5. Connect to the SPN: 
$tenant='7823598c-e4b6-41d0-af11-4f27ea227085'
Connect-AzAccount -ServicePrincipal -Credential $credentials -Tenant $tenant
#6. Create the actual SA: 
New-AzStorageAccount -ResourceGroupName yavorlazarov1-vmss -Name sayavor1 -SkuName Standard_LRS -Location westeurope
#7.Assign the Identity with SAC and remove the Contributor:
$RG = "yavorlazarov1-vmss"
$Sub = "efdec269-328e-4107-97e6-9529a388213c"
# Assign the Storage Account Contributor role to the service principal
New-AzRoleAssignment -ObjectId $SPN.Id -RoleDefinitionName "Storage Account Contributor" -Scope "/subscriptions/$Sub/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/sayavor1"

# Deactivate the Contributor role for the service principal
Remove-AzRoleAssignment -ObjectId $SPN.Id -RoleDefinitionName "Contributor" -Scope "/subscriptions/$Sub/resourceGroups/$RG"

#Get the role assignments for the SPN in question: 
Get-AzRoleAssignment -ObjectId $SPN.Id -Scope /subscriptions/efdec269-328e-4107-97e6-9529a388213c

#Check wether the resource exists:
Get-AzResource
#WARNING: In case you see something different than the storage account in question, that means something did not work during the Role assignments. 




#THIRD MOVEMENT: Create blob container and upload a file there.

#1. Create the  necessary variables to access the SA
$sa = Get-AzStorageAccount -ResourceGroupName yavorlazarov1-vmss -Name sayavor1
$sak = (Get-AzStorageAccountKey -ResourceGroupName yavorlazarov1-vmss -Name $sa.StorageAccountName).Value[0]
$containerName = "testcontainer123"
$blobName = "uploaded-file.txt"
#2. Create the test file which we will upload: 
$filePath = "D:\testFile.txt"

New-Item -ItemType File -Path $filePath

#3. Open the file and file some text inside. Example: "I am the test file!!!"

"I am the test file!!!" | Out-File $filePath

#4. Create the Blob Storage container and upload the file:

$storageContext = New-AzStorageContext -StorageAccountName $sa.StorageAccountName -StorageAccountKey $sak 
New-AzStorageContainer -Context $storageContext -Name $containerName -Permission Blob
#$containerPermissions = Get-AzStorageContainerStoredAccessPolicy -Context $storageContext -Container $containerName
#$containerPermissions[0].PublicAccess = "Blob"
Set-AzStorageBlobContent -Context $storageContext -Container $containerName -Blob $blobName -File $filePath 

#Fourth  Move is to download and read the file.

#Download the File: 
$localFilePath = "C:\Users\Yavor Lazarov\Desktop\localCopy.txt"
Get-AzStorageBlobContent -Context $storageContext -Container $containerName -Blob uploaded-file.txt -Destination $localFilePath

#Verify everything exists: 
# Confirm the download
if (Test-Path $localFilePath) {
    Write-Host "File downloaded successfully. Local file path: $localFilePath"
} else {
    Write-Host "File download failed."
}

# Read the file content
$fileContent = Get-Content -Path $localFilePath

# Display the file content
foreach ($line in $fileContent) {
    Write-Host $line
}


# If you see the text "I am the test file" than everything is set and you can proceed with deleting the blob, the container, the storage account, the Key Vault and the application object.

