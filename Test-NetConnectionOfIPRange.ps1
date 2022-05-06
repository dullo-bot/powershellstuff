function Test-NetConnectionOfIPRange {
    <#
        .SYNOPSIS
            This function lets you run the Test-NetConnection for a specific IP-Range, which you can define via IP and Subnetmask or import from a .csv-file.
        .DESCRIPTION
            The function uses the Test-NetConnection function in a parallel manner for a specified IP-Range of your choice.
            The .csv-file needs a headline with "IP" in it. This function tests all IP-Addresses in the corresponding file.
            If you use the IP-Address and Subnetmask, this function tests all usable IP-Addresses within that subnet (ex. Broadcast-Address)
            As an output, you get an custom object with the IPAddress and the state of the connection, but you have to wait for the function to completely finish every IP.
        .PARAMETER Path
            the local path to the .csv-file, where all IP Addresses are stored
        .PARAMETER IPAddress
            an IP-Address of the subnet, which should be tested
        .PARAMETER Netmask
            the subnet mask of the corresponding IP Address. You can use only /24 to /30-subnets.
        .PARAMETER Port
            the TCP-Port, which should be tested. The default-value is 443.            
        .EXAMPLE
            C:\PS> Test-NetConnectionOfIPRange -Path C:\Users\myname\Desktop\test.csv
        .EXAMPLE
            C:\PS> Test-NetConnectionOfIPRange -IPAddress 10.10.10.10 -Netmask '255.255.255.252' -Port 80

            IPAddress   Success
            ---------   -------
            10.10.10.9    False
            10.10.10.10   False        
        .INPUTS
            .csv-file
                or
            IP-Address and subnetmask
        .OUTPUTS
            [pscustomobject]@{
                IPAddress
                Success
            }
        .NOTES
            Created by: dullo-bot
            Date: 2022-05-06
    #>
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName="CSV")]
        [String]
        $Path,
        [Parameter(ParameterSetName="IP-Range")]
        [String]
        $IPAddress,
        [Parameter(ParameterSetName="IP-Range")]
        [ValidateSet("255.255.255.0","255.255.255.128","255.255.255.192","255.255.255.224","255.255.255.240","255.255.255.248","255.255.255.252")]
        [String]
        $Netmask,
        [Parameter(ParameterSetName="IP-Range")]
        [Parameter(ParameterSetName="CSV")]
        [int]
        $Port=443
    )
    if ($IPAddress -and $Netmask) {
        $IPBits = [int[]]$IPAddress.Split('.')
        $MaskBits = [int[]]$Netmask.Split('.')
        $MaxCounter = 255 - $MaskBits[3]
        $JobList = @()
        $NetworkIDBits = 0..3 | Foreach-Object { $IPBits[$_] -band $MaskBits[$_] }
        #$BroadcastBits = 0..3 | Foreach-Object { $NetworkIDBits[$_] + ($MaskBits[$_] -bxor 255) }
        for ($i = 1; $i -lt $MaxCounter; $i++) {
            $adder = [int[]](0,0,0,$i)
            $LoopIPBits = 0..3 | Foreach-Object { $NetworkIDBits[$_] -bor $adder[$_] }
            $LoopedIPAddress = $LoopIPBits -join "."
            $job = Start-Job -Name "$($LoopedIPAddress)_ConnectionTest" -ScriptBlock { param($LoopedIPAddress,$Port) 
                $ConnectionTest= Test-NetConnection $LoopedIPAddress -Port $Port -WarningAction SilentlyContinue 
                $ReturnObject = @(
                    [pscustomobject]@{IPAddress=$ConnectionTest.ComputerName;Success=$ConnectionTest.TcpTestSucceeded}
                )
                return $ReturnObject
            } -ArgumentList $LoopedIPAddress,$Port
            $JobList += $job.Id
        }
        $result = Wait-Job -Id $JobList | receive-job -keep
        $result | Select-Object IPAddress,Success
    }
    else {
        $array =Import-Csv $Path -Delimiter ","
        $JobList = @()
        foreach ($ip in $array) { 
            $job = Start-Job -Name "$($ip.IP)_ConnectionTest" -ScriptBlock { param($ip,$Port) 
                $ConnectionTest= Test-NetConnection $ip.IP -Port $Port -WarningAction SilentlyContinue 
                $ReturnObject = @(
                    [pscustomobject]@{IPAddress=$ip.IP;Erreichbar=$ConnectionTest.TcpTestSucceeded}
                )
                return $ReturnObject
            } -ArgumentList $ip,$Port
            $JobList += $job.Id
        }
        $result = Wait-Job -Id $JobList | receive-job -keep
        $result | Select-Object IPAddress,Success
    }
}
