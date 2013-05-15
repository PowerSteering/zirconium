Zirconium - Graphite Collector for Windows Servers
Version 0.11 3/1/2013 lwintringham@psteering.com

#### WARNING! ####

This was written by a Linux Engineer and Perl programmer who learned powershell and Windows just for this application. Input, feedback, improvements and contributions are desired.

#################

LICENSE
  Copyright (C) 2013  Lee Wintringham, PowerSteering Software

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, version 3 of the License.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

GRAPHITE
  http://graphite.wikidot.com/
  
HOW IT WORKS
  1. Zirconium uses WMI to gather various statistics.
  2. Zirconium attempts to automatically enumerate Disks, Network Cards, CPUs, and SqlServer.
  3. Data is sent via a tcp stream to Graphite in the format <path> <value> <time>
     Where 'path' is a '.' separated string. i.e Computers.cambridge.server1.CPU.cpu0.PercentIdle
     'time' must be a unix timestamp in UTC

INSTALLATION
  Windows 2003: Double Click 'install.bat' or run from cmd.
  Windows 2008: Right click 'install.bat' and select "Run as Administrator".
	 
MANUAL INSTALLATION 
  1. Download zirconium-(version).zip and extract.
  2. Copy the contents of the bin/ directory to "c:\zirconium".
  3. Open Powershell and set execution policy: "Set-Executionpolicy unrestricted"
  4. Edit sendStats.bat and ensure path to zirconium.ps1 is correct.
  5. Run sendStats.bat from the command line and check for errors. Verify host appears in graphite after running.
  6. Schedule Job.
    6a. Schedule sendStats.bat to run every 5 minutes for the rest of the day.
    6b. Create a daily reoccuring schedule to run sendStats every 5 minutes midnight-11:55PM.
    -or- run the following command: 
      schtasks /create /sc minute /mo 5 /tn "Zirconium" /tr "c:\zirconium\sendStats.bat" /st 00:00

UNINSTALL
  1. Delete scheduled task. Either through Windows Task Scheduler or with the below command:
     schtasks /delete Zirconium
  2. Delete directory c:\zirconium	 
 
CONFIGURATION
  path - TLD for Graphite Data
  remote host and port - Graphite Server
  log - Log File

TODO 
  - Fix Logging
