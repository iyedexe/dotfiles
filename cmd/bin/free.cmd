@echo off
:: free  - memory in MB
powershell -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; '{0,-6}{1,10}{2,10}{3,10}' -f '(MB)','total','used','free'; '{0,-6}{1,10:N0}{2,10:N0}{3,10:N0}' -f 'Mem:',($o.TotalVisibleMemorySize/1KB),(($o.TotalVisibleMemorySize-$o.FreePhysicalMemory)/1KB),($o.FreePhysicalMemory/1KB)"
