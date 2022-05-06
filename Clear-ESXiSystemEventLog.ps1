function Clear-ESXiSystemEventLog
{  
    <#
    .SYNOPSIS
        Deletes all Logs of the SystemEventLog on an ESXi, if there are more than 350 entries
    .DESCRIPTION
        This function checks the SystemEventLog entries for all specified ESXi hosts (either of the vCenter, Datacenter, Cluster or Folder).
        If the counter of the SEL is above the Parameter LogNumber, than the SEL is cleared.
        This function prevents the error 'Host hardware sensor status'
    .PARAMETER Location
        Specify which ESXi should be checked. You can filter by Datacenter, Cluster or Folder
        If you leave this parameter unitialized, it will check all ESXi hosts on the vCenter you are connected
    .PARAMETER LogNumber
        This is the trigger for the SEL to be deleted. If the ESXi has more Logs than this Parameter, than the SEL is cleared.
        The Default-Value is 350.
    .EXAMPLE
        C:\PS> Connect-ViServer -Server "yourVcenterFQDN"
        C:\PS> Clear-ESXiSystemEventLog -verbose
    .EXAMPLE
        C:\PS> Connect-ViServer -Server "yourVcenterFQDN"
        C:\PS> Clear-ESXiSystemEventLog -Location "yourCluster"
    .EXAMPLE
        C:\PS> Connect-ViServer -Server "yourVcenterFQDN"
        C:\PS> Clear-ESXiSystemEventLog -Location "yourDC" -LogNumber 260 -verbose
    .INPUTS
        none
    .OUTPUTS
        none
    .NOTES
        Created by: dullo-bot
        Date: 2022-05-06
    #>
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Location,
        [Parameter()]
        [Int]
        $LogNumber=350
    )
    if ($Location)
    {
        $VMHosts = Get-VMHost -Location $Location
    }
    else
    {
        $VMHosts = Get-VMHost
    }
    foreach ($ESXiHost in $VMHosts)
    {
        $HostHealthStatusSystemView = (Get-View -Id (Get-View $ESXiHost -Verbose:$false).ConfigManager.HealthStatusSystem -Verbose:$false)
        $SELCounter = (($HostHealthStatusSystemView).FetchSystemEventLog() | Measure-Object).count
        Write-Verbose "$($ESXiHost.name) has $SELCounter System Events in SEL"
        if ($SELCounter -gt $LogNumber)
        {
            Write-Verbose "Clearing SEL on $($ESXiHost.name)"
            $HostHealthStatusSystemView.ClearSystemEventLog()
        }
    }
}
