function StartingPackage {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName Microsoft.VisualBasic
    Connect-AzAccount
    Set-AzContext -Subscription "Visual Studio Professional Subscription"
}

function Add-RG {
    [CmdletBinding()]
    param(
        $name,
        $location,
        $tag
       
    )
    New-AzResourceGroup -Name $name -Location $location -Tag $tag 
}
function Add-Vnet {
    [CmdletBinding()]
    param(
        $RG, 
        $Location, 
        $Tag, 
        $VNETName, 
        $VNETAddressSpace,
        $Subnet
    )
    try {
        New-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RG -AddressPrefix $VNETAddressSpace -Location $Location -Subnet $Subnet
    }
    catch {
        Write-Error "Creation of VNET failed for some reason. Look it up for the reason ;)"
    }
}

function Add-NIC {
    param(
       
        [Parameter(Mandatory = $true)]
        $RG,
        [Parameter(Mandatory = $true)]
        [ValidateSet("West Europe", "North Europe")]
        $Location,
        [Parameter(Mandatory = $true)]
        $VnetName,
        [Parameter(Mandatory = $true)]
        $SubnetName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("nicyavorlaz1", "yavornic1")]
        $nicName
    )
    $Vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $RG 
    $Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $Vnet
    New-AzNetworkInterface -Name $nicName -ResourceGroupName $RG -Location $Location -Subnet $Subnet
}
function Add-PublicIP {

    [CmdletBinding()]
    param(
        $RG,
        $Location,
        $IPName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Standard")]
        $SKU,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Static")]
        $AllocationMethod,

        [Parameter(Mandatory = $true)]
        [ValidateSet("yavornic1", "nicyavorlaz1")]
        $nicName
    )
    $publicIP = New-AzPublicIpAddress -Name $IPName -ResourceGroupName $RG -Location $Location -AllocationMethod $AllocationMethod
    <#In order to associate the IP address with a NIC we need to follow four steps:
      1. Take the NIC configuration and assign it to a variable
      2. Take the IP Config of the Network interface and assign it to a variable.
      3. Set the network interface ip config with the new Public IP.
      4. Set the newly UPDATED IP config into the entire NIC.
    #>
     
    #1.
    $NIC = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $RG
    #2.
    $IPConfig = Get-AzNetworkInterfaceIpConfig -NetworkInterface $NIC
    #3.
    $NIC | Set-AzNetworkInterfaceIpConfig -PublicIpAddress $publicIP -Name $IPConfig.Name
    #4.
    $NIC | Set-AzNetworkInterface

}

function Add-NSG {
    [CmdletBinding()]
    param(
       
        [Parameter(Mandatory = $true)]
        $RG,
        [Parameter(Mandatory = $true)]
        [ValidateSet("West Europe", "North Europe")]
        $Location,
        [Parameter(Mandatory = $true)]
        $NSGname,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Allow_RDP")]
        $RuleName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Allow", "Deny")]
        $Access,
        [Parameter(Mandatory = $true)]
        [ValidateSet("TCP", "UDP")]
        $Protocol, 
        [Parameter(Mandatory = $true)]
        [ValidateSet("Inbound", "Outbound")]
        $Direction, 
        [Parameter(Mandatory = $true)]
        $Priority,
        [Parameter(Mandatory = $true)]
        $SourceAddressPrefix, 
    
        [Parameter(Mandatory = $true)]
        $DestinationPortRange,      
    
        $VNETName, 
        $SubnetName,
        $SubnetAddress 
     

    )
    #Create the Network Security Group rule: 
    $secRule = New-AzNetworkSecurityRuleConfig -Name $RuleName -Description $RuleName -Access $Access -Protocol $Protocol -Direction $Direction -SourceAddressPrefix $SourceAddressPrefix -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $DestinationPortRange -Priority $Priority
    $NSGSet = New-AzNetworkSecurityGroup -Name $NSGname -ResourceGroupName $RG -Location $Location -SecurityRules $secRule
    $VNET = Get-AzVirtualNetwork -Name $VNETName -ResourceGroupName $RG 
    Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNET -Name $SubnetName -NetworkSecurityGroup $NSGSet -AddressPrefix $SubnetAddress
}
function  Add-KeyVault {
    param (
        $vaultName,
        $RG, 
        $Location
    )
    try {
        New-AzKeyVault -Name $vaultName -ResourceGroupName $RG -Location $Location 
    }
    catch {
        Write-Warning "The Key Vault might be existing"
    }
    $MachineUser = Read-Host "User"
    $MachinePass = Read-Host "Password"
    $MachineUser = ConvertTo-SecureString $MachineUser -Force -AsPlainText
    $MachinePass = ConvertTo-SecureString $MachinePass -Force -AsPlainText

    Set-AzKeyVaultSecret -VaultName $vaultName -Name "Machineusersecret" -SecretValue $MachineUser
    Set-AzKeyVaultSecret -VaultName $vaultName -Name "Machinepasssecret" -SecretValue $MachinePass
   
    $MachineUsername = Get-AzKeyVaultSecret -VaultName $vaultName -Name "Machineusersecret" 
    $MachinePassword = Get-AzKeyVaultSecret -VaultName $vaultName -Name "Machinepasssecret" 
    $creds = [PSCustomObject]@{
        User = $MachineUsername
        Password = $MachinePassword
    }
    return $creds
}
function Add-VM {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("yavorTestVM1")]
        $VMName,
        [Parameter(Mandatory = $true)]
        [ValidateSet("Standard_DS2_v2")]
        $VMSize,
        [Parameter(Mandatory = $true)]
        $Location,
        [Parameter(Mandatory = $true)]
        $nicName,
        [Parameter(Mandatory = $true)]
        $RG,
        [Parameter(Mandatory = $true)]
        [string]$UserName,
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    $SecureString = ConvertTo-SecureString -String "Yavkata2012!" -AsPlainText -Force
    $NetInt = Get-AzNetworkInterface -Name $nicName -ResourceGroupName $RG
    $VMconfig = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $Credential = New-Object System.Management.Automation.PSCredential ("yavor", $SecureString); 

    Set-AzVMOperatingSystem -VM $VMconfig -ComputerName $VMName -Windows -Credential $Credential
    Set-AzVMSourceImage -VM $VMconfig -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2019-Datacenter" -Version "latest" 

    $Vm = Add-AzVMNetworkInterface -VM $VMconfig -Id $NetInt.Id

    Set-AzVMBootDiagnostic -Disable -VM $Vm
    
    New-AzVM -ResourceGroupName $RG -Location $Location -VM $Vm 

}

function Create-Infra {
    StartingPackage
    $params = @{
        startCreation    = Read-Host "You wanna start creating the Infra? y/n"
        RG               = "yavortestdeploy"
        Location         = "North Europe"
        Tag              = @{State = "Created" }
        vnetSpecifics    = @{
            Name               = "yavorlazarovtest-vnet"
            AddressSpace       = "10.0.0.0/16"
            SubnetName         = "default"
            SubnetAddressSpace = "10.0.0.0/24"
        }
        publicIP         = @{
            name             = "yavorlazarovtest-IP"
            AllocationMethod = "Static"
            SKU              = "Standard"
        }
        NetworkInterface = "yavornic1"
        NSGSpec          = @{
            Name                 = "yavorNSG"
            ruleName             = "Allow_RDP"
            Access               = "Allow"
            Protocol             = "TCP"
            Direction            = "Inbound"
            SourceAddress        = "65.153.77.124"
            DestinationPortRange = 3389
            Priority             = 104
        }
        vaultName        = "yavortestdeploy-vault"
    }
    
    if ($params.startCreation -eq 'y') {
        Add-RG -name $params.RG -location $params.Location -tag $params.Tag
        $subNetconfig = New-AzVirtualNetworkSubnetConfig -Name $params.vnetSpecifics.SubnetName -AddressPrefix $params.vnetSpecifics.SubnetAddressSpace
        Add-Vnet -RG $params.RG -Location $params.Location -VNETName $params.vnetSpecifics.Name -VNETAddressSpace $params.vnetSpecifics.AddressSpace -Subnet $subNetconfig -Tag $params.Tag    
        Add-NIC -RG $params.RG -Location $params.Location -VnetName $params.vnetSpecifics.Name -SubnetName $params.vnetSpecifics.SubnetName -nicName $params.NetworkInterface 
        Add-PublicIP -RG $params.RG -Location $params.Location -IPName $params.publicIP.name -nicName $params.NetworkInterface -SKU $params.publicIP.SKU -AllocationMethod $params.publicIP.AllocationMethod
        Add-NSG -RG $params.RG -Location $params.Location -NSGname $params.NSGSpec.Name -RuleName $params.NSGSpec.ruleName -Access $params.NSGSpec.Access -Protocol $params.NSGSpec.Protocol -Direction $params.NSGSpec.Direction -SourceAddressPrefix $params.NSGSpec.SourceAddress -Priority $params.NSGSpec.Priority -DestinationPortRange $params.NSGSpec.DestinationPortRange -VNETName $params.vnetSpecifics.Name -SubnetName $params.vnetSpecifics.SubnetName -SubnetAddress $params.vnetSpecifics.SubnetAddressSpace
        $credentials = Add-KeyVault -RG $params.RG -vaultName $params.vaultName -Location $params.Location
        Add-VM -VMName "yavorTestVM1" -VMSize Standard_DS2_v2 -Location "North Europe" -nicName $params.NetworkInterface -RG $params.RG -UserName $credentials.User -Password $credentials.Password
        Add-StorageAccount -RG $params.RG -Location $params.Location      
    }
}
function deleteInfra {
    param(
        $key,
        $value,
        $vaultName, 
        $location
    )
    StartingPackage
    
    $Rg = Get-AzResourceGroup -Tag @{$key = $value }
    Remove-AzResourceGroup -Name $RG.ResourceGroupName -Force 
    try {
        Remove-AzKeyVault -VaultName $vaultName -InRemovedState -Location $location -Force
    }
    catch {
        Write-Warning "Already Removed ;) "
    }
}
function Add-StorageAccount {
    [CmdletBinding()]
    param (
        $RG,
        $Location
    )
    $containerName = "data"
    New-AzStorageAccount -Name "yavorlazarovteststorage" -ResourceGroupName $RG -Location $Location -Kind BlobStorage -AccessTier Hot -SkuName Standard_LRS
    $storageAccount = Set-AzStorageAccount -Name "yavorlazarovteststorage" -ResourceGroupName $RG 
    New-AzStorageContainer -Name $containerName -Context $storageAccount.Context -Permission Blob
    $BlobObject = {
        FileLocation = "C:\Users\yavor\Desktop\Scripts and Toools\IISserverInstall.ps1"
        ObjectName = "IISserverInstall.ps1"
    }
    Set-AzureStorageBlobContent -Context $storageAccount.Context -Container $containerName -File $BlobObject.FileLocation -Blob $BlobObject.ObjectName
    
}
function main {
    $choice = Read-Host "Deleting or Creating?del/create"
    if ($choice -eq "create") {
        Create-Infra 
    }
    elseif ($choice -eq "del") {
        deleteInfra -key "State" -value "Created" -vaultName "yavortestdeploy-vault" -location northeurope
    }
}
main  

