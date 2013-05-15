# Zirconium - Graphite Collector for Windows Servers
# Version 0.11 3/1/2013 lwintringham@psteering.com
#
# LICENSE
#  Copyright (C) 2013  Lee Wintringham, PowerSteering Software
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, version 3 of the License.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#	
# HOW IT WORKS
#  1. Zirconium uses WMI to gather various statistics.
#  2. Zirconium attempts to automatically enumerate Disks, Network Cards, CPUs, and SqlServer.
#  3. Data is sent via a tcp stream to Graphite in the format <path> <value> <time>
#     Where 'path' is a '.' separated string. i.e Computers.cambridge.server1.CPU.cpu0.PercentIdle
#     'time' must be a unix timestamp in UTC
#
# MANUAL INSTALLATION 
#  1. Download zirconium-(version).zip and extract.
#  2. Copy the contents of the bin/ directory to "c:\zirconium".
#  3. Open Powershell and set execution policy: "Set-Executionpolicy unrestricted"
#  4. Edit sendStats.bat and ensure path to zirconium.ps1 is correct.
#  5. Run sendStats.bat from the command line and check for errors. Verify host appears in graphite after running.
#  6. Shedule Job.
#    6a. Schedule sendStats.bat to run every 5 minutes for the rest of the day.
#    6b. Create a daily reoccuring schedule to run sendStats every 5 minutes midnight-11:55PM.
#    -or- run the following command: 
#      schtasks /create /sc minute /mo 5 /tn "Zirconium" /tr "c:\zirconium\sendStats.bat" /st 00:00
# 
#  TODO: Fix Logging
#
# CONFIGURATION
# path - TLD for Graphite Data
# remote host and port - Graphite Server
# log - Log File

$path = "servers.windows."	
$remoteHost = "graphite.yourdomain.com"
$port = 2003
$log = "C:\zirconium\zirconiumLog.txt"

#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#
$socket = new-object System.Net.Sockets.TcpClient($remoteHost, $port)
$hostname =  Invoke-Command -ScriptBlock {hostname}
$prefix = $path + $hostname + '.'
$ts = [int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime() -uformat %s))
$tsLog = Get-Date
$data = @{}

Write-Output "Zirconium Collector for Graphite"
Write-Output "Version 0.11 3/1/2013 `n"

# CPU
Write-Output "Cheking CPU..."
$wmiCpu = Get-WmiObject Win32_PerfFormattedData_PerfOS_Processor

foreach ($nCpu in $wmiCpu) {
  $cpuId = ($nCpu).Name
  Write-Output "Found CPU $cpuId"
  $data.Add("CPU.$cpuId.InterruptsPersec",($nCpu).InterruptsPersec)
  $data.Add("CPU.$cpuId.PercentUserTime",($nCpu).PercentUserTime)
  $data.Add("CPU.$cpuId.PercentPrivilegedTime",($nCpu).PercentPrivilegedTime)
  $data.Add("CPU.$cpuId.PercentProcessorTime",($nCpu).PercentProcessorTime)
  $data.Add("CPU.$cpuId.PercentInterruptTime",($nCpu).PercentInterruptTime)
  $data.Add("CPU.$cpuId.PercentIdle",($nCpu).PercentIdleTime)
}

# Network
Write-Output "Cheking Network..."
$netTcp = get-wmiobject Win32_PerfFormattedData_Tcpip_TCPv4
$data.Add("Network.TCP.ConnEstablished",($netTcp).ConnectionsEstablished)

$network = Get-WmiObject win32_networkadapterconfiguration -Filter 'ipenabled = "true"'| Select-Object IPAddress,Description

foreach ($nic in $network) {
  # This may contain an ipv6 address, we only want the ipv4 stuff
  $nicIp = ($nic).IPAddress -match "^(\d+\.\d+\.\d+\.\d+)"
  $nicIp = $nicIp -replace "\.","_"
  #
  $nicName = ($nic).Description -replace "#","_" 
  $nicName = $nicName -replace "\(","[" 
  $nicName = $nicName -replace "\)","]"
  $nicName = $nicName -replace "\/","_"
  Write-Output "Found NIC $nicName ($nicIp)"

  $netBytesSentSec = [int]((Get-Counter -Counter "\network interface($nicName)\bytes sent/sec").countersamples | select -property cookedvalue).cookedvalue
  $netBytesReceivedSec = [int]((Get-Counter -Counter "\network interface($nicName)\bytes received/sec").countersamples | select -property cookedvalue).cookedvalue
  $netPacketsSentSec = [int]((Get-Counter -Counter "\network interface($nicName)\packets sent/sec").countersamples | select -property cookedvalue).cookedvalue
  $netPacketsReceivedSec = [int]((Get-Counter -Counter "\network interface($nicName)\packets received/sec").countersamples | select -property cookedvalue).cookedvalue

  $data.Add("Network.$nicIp.BytesSentSec",$netBytesSentSec)
  $data.Add("Network.$nicIp.BytesReceiveSec",$netBytesReceivedSec)
  $data.Add("Network.$nicIp.PacketsSentSec",$netPacketsSentSec)
  $data.Add("Network.$nicIp.PacketsReceiveSec",$netPacketsReceivedSec)
}

# Memory
Write-Output "Cheking Memory..."
$memTotal =  (get-wmiobject Win32_ComputerSystem).TotalPhysicalMemory
$data.Add("Memory.Total",$memTotal)

$wmiMem = Get-WmiObject Win32_PerfFormattedData_PerfOS_Memory

$memFree = ($wmiMem).AvailableBytes
$memBytesUsed = $memTotal - $memFree

$data.Add("Memory.BytesFree",$memFree)
$data.Add("Memory.BytesUsed",$memBytesUsed)
$data.Add("Memory.CachedBytes",($wmiMem).CacheBytes)
$data.Add("Memory.CommittedBytes",($wmiMem).CommittedBytes)
$data.Add("Memory.CommittedPercent",($wmiMem).PercentCommittedBytesInUse)
$data.Add("Memory.CommitLimit",($wmiMem).CommitLimit)

# System
Write-Output "Cheking System..."

$wmiSys = Get-WmiObject Win32_PerfFormattedData_PerfOS_System
$data.Add("System.SystemCallsSec",($wmiSys).SystemCallsPersec)
$data.Add("System.ProcsTotal",($wmiSys).Processes)
$data.Add("System.ThreadsTotal",($wmiSys).Threads)
$data.Add("System.ProcessorQueueLength",($wmiSys).ProcessorQueueLength)

$wmiServiceOk = Get-WmiObject -query "Select ExitCode from Win32_Service where State = 'Running' and Status = 'OK'"
$data.Add("System.ServicesRunning",($wmiServiceOk).Count)

$wmiServiceBad = Get-WmiObject -query "Select ExitCode from Win32_Service where Status != 'OK'"
if (!$wmiServiceBad.count) {
  $data.Add("System.ServicesNotOK",'0')
} else {
  $data.Add("System.ServicesNotOK",($wmiServiceBad).Count)
}

# Disk
Write-Output "Cheking Disks..."

# DriveType 3 = Local Disk
$wmiDisk = Get-WmiObject -query "Select * from Win32_Volume where DriveType = '3' and Label != 'System Reserved'"

foreach ($nDisk in $wmiDisk) {
  $diskLetter = ($nDisk).DriveLetter
  $diskLabel = ($nDisk).Label

  Write-Output "Found Logical Disk $diskLetter ($diskLabel)"

  $diskUsedBytes = ($nDisk).Capacity - ($nDisk).Freespace

  $data.Add("Disk.$diskLetter.BytesUsed",$diskUsedBytes)
  $data.Add("Disk.$diskLetter.BytesFree",($nDisk).FreeSpace)
  $data.Add("Disk.$diskLetter.CapacityBytes",($nDisk).Capacity)

  [float]$usedRatio = ($diskUsedBytes) / ($nDisk.Capacity)
  $diskPercentUsed = [math]::round(($usedRatio * 100),2)
  $data.Add("Disk.$diskLetter.UsedPercent",$diskPercentUsed)

  # I/O Checks
  $diskReadSec = [int]((Get-Counter -Counter "\LogicalDisk($diskLetter)\Disk Read Bytes/sec").countersamples | select -property cookedvalue).cookedvalue
  $diskWriteSec = [int]((Get-Counter -Counter "\LogicalDisk($diskLetter)\Disk Write Bytes/sec").countersamples | select -property cookedvalue).cookedvalue
  $data.Add("Disk.$diskLetter.ReadBtyeSec",$diskReadSec)
  $data.Add("Disk.$diskLetter.WriteByteSec",$diskWriteSec)
}

if (Get-WmiObject -query "Select ProcessId from Win32_Process where Name = 'sqlservr.exe'") {
  $sqlHost = 'yes'
  Write-Output "SQLServer Host: YES"
}
else {
  Write-Output "SQLServer Host: NO"
} 

# SQL Server
if ($sqlHost -eq 'yes') {
  Write-Output "Cheking SQL Server..."

  # SQL CPU
  $cpuProcSqlserver = [int]((Get-Counter -Counter "\Process(sqlservr)\% Processor Time").countersamples | select -property cookedvalue).cookedvalue
  $data.Add("CPU.sqlserverProcess",$cpuProcSqlserver)

  # Database Instances
  $dbNames = GET-WMIOBJECT win32_perfformatteddata_mssqlserver_sqlserverdatabases | Select-Object Name,DataFilesSizeKB,ActiveTransactions,LogFilesSizeKB,PercentLogUsed

  foreach ($nDb in $dbNames) {
    $realName = ($nDb).Name
    Write-Output "Checking DB $realName"
    $curName = ($nDb).Name -replace "\.","_"
    $dataFileSizeBytes = ($nDb).DataFilesSizeKB * 1024
    $data.Add("SQL.Database.$curname.DataFilesSizeBytes",$dataFileSizeBytes)
    $data.Add("SQL.Database.$curname.ActiveTransactions",($nDb).ActiveTransactions)
    $LogFilesSizeKB = ($nDb).LogFilesSizeKB
    $LogFilesSizeBytes = $LogFilesSizeKB * 1024
    $data.Add("SQL.Database.$curname.LogFilesSizeBytes",($nDb).LogFilesSizeBytes)
    $data.Add("SQL.Database.$curname.PercentLogUsed",($nDb).PercentLogUsed)  
  }
  # SQL Memory 
  $sqlMem = GET-WMIOBJECT Win32_PerfFormattedData_MSSQLSERVER_SQLServerMemoryManager
  foreach ($nMem in $sqlMem) {
    $sqlTotalServerMemoryBytes = ($nMem).TotalServerMemoryKB * 1024
    $sqlTargetServerMemoryBytes = ($nMem).TargetServerMemoryKB * 1024
    $sqlCacheMemBytes = ($nMem).SQLCacheMemoryKB * 1024
    $sqlOptimizerMemoryBytes = ($nMem).OptimizerMemoryKB * 1024
    $sqlMaximumWorkspaceMemoryBytes = ($nMem).MaximumWorkspaceMemoryKB * 1024
    $sqlConnectionMemoryBytes = ($nMem).ConnectionMemoryKB * 1024
    $sqlLockMemoryBytes = ($nMem).LockMemoryKB * 1024
    $sqlLockBlocks = ($nMem).LockBlocks
    $sqlLockBlocksAllocated = ($nMem).LockBlocksAllocated
    $sqlLockOwnerBlocks = ($nMem).LockOwnerBlocks
    $sqlLockOwnerBlocksAllocated = ($nMem).LockOwnerBlocksAllocated

    $data.Add("SQL.Memory.TotalServerMemoryBytes",$sqlTotalServerMemoryBytes)
    $data.Add("SQL.Memory.TargetServerMemoryBytes",$sqlTargetServerMemoryBytes)
    $data.Add("SQL.Memory.CacheMemBytes",$sqlCacheMemBytes)
    $data.Add("SQL.Memory.OptimizerMemoryBytes",$sqlOptimizerMemoryBytes)
    $data.Add("SQL.Memory.MaximumWorkspaceMemoryBytes",$sqlMaximumWorkspaceMemoryBytes)
    $data.Add("SQL.Memory.ConnectionMemoryBytes",$sqlConnectionMemoryBytes)
    $data.Add("SQL.Memory.LockMemoryBytes",$sqlLockMemoryBytes)
    $data.Add("SQL.Memory.LockBlocks",$sqlLockBlocks)
    $data.Add("SQL.Memory.LockBlocksAllocated",$sqlLockBlocksAllocated)
    $data.Add("SQL.Memory.LockOwnerBlocks",$sqlLockOwnerBlocks)
    $data.Add("SQL.Memory.LockOwnerBlocksAllocated",$sqlLockOwnerBlocksAllocated)
          
  }
  # SQL Errors
  $sqlErrs = GET-WMIOBJECT Win32_PerfFormattedData_MSSQLSERVER_SQLServerSQLErrors

  foreach ($nErrs in $sqlErrs) {
    $errHead = ($nErrs).Name -replace " ","_"
    $errData = ($nErrs).ErrorsPersec
    $data.Add("SQL.Errors.$errHead",$errData)
  }
  # Global Transactions
  $sqlTransactions = GET-WMIOBJECT Win32_PerfFormattedData_MSSQLSERVER_SQLServerTransactions
  $data.Add("SQL.Transactions",($sqlTransactions).transactions)
  
  # Waits
  $wmiSqlWait = Get-WmiObject -query "Select * from Win32_PerfFormattedData_MSSQLSERVER_SQLServerWaitStatistics where Name = 'Waits in progress'"
  foreach ($nWait in $wmiSqlWait) {
   $data.Add("SQL.WaitStats.LockWaits",($nWait).Lockwaits)
   $data.Add("SQL.WaitStats.Logbufferwaits",($nWait).Logbufferwaits)
   $data.Add("SQL.WaitStats.Logwritewaits",($nWait).Logwritewaits)
   $data.Add("SQL.WaitStats.Memorygrantqueuewaits",($nWait).Memorygrantqueuewaits)
   $data.Add("SQL.WaitStats.NetworkIOwaits",($nWait).NetworkIOwaits)
  }

  # Other Stats
  $sqlGenStats = Get-WmiObject Win32_PerfFormattedData_MSSQLSERVER_SQLServerGeneralStatistics
  $data.Add("SQL.LogicalConnections",($sqlGenStats).LogicalConnections)
  $data.Add("SQL.ActiveTempTables",($sqlGenStats).ActiveTempTables)
  $data.Add("SQL.UserConnections",($sqlGenStats).UserConnections)

}

# Collector Metrics
$tsEnd = [int][double]::Parse($(Get-Date -date (Get-Date).ToUniversalTime() -uformat %s))
$runTime = $tsEnd - $ts
$items = $data.Count
$data.Add("zirconium.RunTime",$runTime)

# Send to Graphite
$stream = $socket.GetStream() 
$writer = new-object System.IO.StreamWriter $stream

$data.Keys | % { 
  $buffer = $prefix + $_ + " " + $data.Item($_) + " " + $ts
  $writer.WriteLine($buffer)
  #Write-Output "$tsLog $buffer" |Out-File $log -append
  #Write-Output $buffer
  $writer.Flush() 
}
Write-Output "$tsLog Gathered $items Metrics in $runTime seconds"

#Write-Output "$tsLog Gathered $items Metrics in $runTime seconds" |Out-File $log -append
#Write-Output "#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#~#" |Out-File $log -append
$socket.Close()

# Hold Dialog Open for a few Seconds
sleep 30
