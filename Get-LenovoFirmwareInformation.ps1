function Get-LenovoFirmwareInformation {
        <#
        .SYNOPSIS
            This function checks whether  a set of firmware packages or a single firmware package is installed on a specific host or set of hosts
        .DESCRIPTION
            This function can be used to automatically output a list of objects that do not have one or more firmware packages installed.
            The output contains: Server name, Server UUID, as well as a subordinate object FirmwareToPatch, which contains Component name and FixId of the firmware packages.
            All servers are checked for installed firmware states and the output object is formed dynamically so that only the packages that are actually needed can be installed if the firmware states are different.
        .EXAMPLE
            PS > Get-LenovoFirmwareInformation -FirmwarePackage @("lnvgy_fw_uefi_ive176h-3.20_anyos_32-64","lnvgy_fw_xcc_cdi388m-7.80_anyos_noarch") -Servername "myLocation"
            Cmdlet Get-Credential an der Befehlspipelineposition 1
            Geben Sie Werte für die folgenden Parameter an:
            User: myuser
            Password for user myuser: ****************
            Insert FQDN of the LXCA: myLXCA.mydomain.com
            WARNING: Firmware-Package lnvgy_fw_uefi_ive176h-3.20_anyos_32-64 for myServer1-myLocation not found
            WARNING: Firmware-Package lnvgy_fw_xcc_cdi388m-7.80_anyos_noarch for myServer1-myLocation not found
            
            Servername      UUID                             FirmwareToPatch
            ----------      ----                             ---------------
            Srv2-myLocation XXXXXYYYYYZZZZZAAAAABBBBBCCCCCDD {@{ComponentName=UEFI; FixId=lnvgy_fw_uefi_ive176h-3.20_anyos_32-64}, @{ComponentName=XCC; FixId=lnvgy_fw_xcc_cdi388m-7.80_anyos_noarch}}
            Srv3-myLocation RRTTJJJJJJJCCCCPPPPUUUUUIIIIOOOO {@{ComponentName=UEFI; FixId=lnvgy_fw_uefi_ive176h-3.20_anyos_32-64}, @{ComponentName=XCC; FixId=lnvgy_fw_xcc_cdi388m-7.80_anyos_noarch}}
            Srv4-myLocation DDDDDGGGGGHHHHOOOOOIIIIILLLLLSSS {@{ComponentName=UEFI; FixId=lnvgy_fw_uefi_ive176h-3.20_anyos_32-64}, @{ComponentName=XCC; FixId=lnvgy_fw_xcc_cdi388m-7.80_anyos_noarch}}
            Srv5-myLocation MMMNNNNKKKKLLLLWWWWWRRRREEEEEVVV {@{ComponentName=UEFI; FixId=lnvgy_fw_uefi_ive176h-3.20_anyos_32-64}, @{ComponentName=XCC; FixId=lnvgy_fw_xcc_cdi388m-7.80_anyos_noarch}}
        .Parameter FirmwarePackage
            The name of the firmware-package(s). It can be a string or an array of Strings and it needs to be the full name of the package, e.g.:lnvgy_fw_uefi_ive176j-3.22_anyos_32-64
        .Parameter Servername
            You can filter the names of the servers with this parameter. You can simply write the whole name of a server for checking single servers or a part of the name. 
        .INPUTS
            FirmwarePackage: String[]
            Servername: String
        .OUTPUTS
            PSCustomObject
        .NOTES
            Created by: dullo-bot
            Date: 10.05.2022
        #>     
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [String[]]
        $FirmwarePackage,
        [Parameter(Mandatory=$True)]
        [String]
        $Servername
    )
    begin{
        if (!(Get-LXCAConnection)) {
            $Credentials = Get-Credential
            $Connection = Connect-LXCA -Host (Read-Host "Insert FQDN of the LXCA") -Credential $Credentials -SkipCertificateCheck
        }
        else {
            $Connection = Get-LXCAConnection
        }
        $ServerUpdateObject=@()
        $FirmwareUpdateObject=@()
    }
    process{
        # there is no filter parameter on Get-LXCARackServer, so we need to filter afterwards with Where-Object and select just the name, uuid, machinetype and firmwares
        $Servers = Get-LXCARackServer | Where-Object -Property "Name" -like -value "*$($Servername)*" | Select-Object Name,Uuid,MachineType,Firmwares
        foreach ($Server in $Servers) {
            foreach ($SinglePackage in $FirmwarePackage) {
            #search for the update packages for each server
            $FoundUpdatePackage = Get-LXCAUpdatePackage -MachineType $Server.MachineType -Connection $Connection | Where-Object -Property "FixId" -EQ -Value $SinglePackage
                if ($FoundUpdatePackage) {
                    #check version of the installed package and the desired package
                    if ($FoundUpdatePackage.Version -ne ($Server.Firmwares | Where-Object -Property Type -eq -Value "$($FoundUpdatePackage.ComponentType)").Version) {
                        Write-Verbose "adding $($SinglePackage) to $($Server.Name).Patchliste"
                        $FirmwareUpdateObject += [PSCustomObject]@{
                            ComponentName = $FoundUpdatePackage.ComponentName
                            FixId = $SinglePackage
                        }
                    } #endif
                    else {
                        Write-Verbose "$($Server.Name) has already installed $($SinglePackage)"
                    }
                } #endif 
                else {
                Write-Warning "FirmwarePackage $($SinglePackage) for $($Server.Name) not found"
                }
            } #end foreach fw package
            if ($FirmwareUpdateObject) {
                $ServerUpdateObject += [PSCustomObject]@{
                    Servername = $Server.Name
                    UUID = $Server.Uuid
                    FirmwareToPatch = $FirmwareUpdateObject
                }
                $FirmwareUpdateObject=@()
            } #endif
        } #end foreach server
    } #end process
    end{
        return $ServerUpdateObject
    }
}
