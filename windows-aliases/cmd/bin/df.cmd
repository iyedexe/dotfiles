@echo off
:: df [-h]  - disk usage per drive
powershell -NoProfile -Command "'{0,-6}{1,10}{2,10}{3,10}{4,6} {5}' -f 'Drive','Size','Used','Avail','Use%%','Label'; Get-CimInstance Win32_LogicalDisk | Where-Object Size | ForEach-Object { $u=$_.Size-$_.FreeSpace; $h={param($b) foreach($x in 'B','K','M','G','T'){ if($b -lt 1024){ return ('{0:0.#}{1}' -f $b,$x) }; $b/=1024 }; '{0:0.#}P' -f $b}; '{0,-6}{1,10}{2,10}{3,10}{4,5}%% {5}' -f $_.DeviceID,(& $h $_.Size),(& $h $u),(& $h $_.FreeSpace),[int](100*$u/$_.Size),$_.VolumeName }"
