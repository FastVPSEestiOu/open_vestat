open_vestat
===========

**open\_vestat** - script for output top 20 openvz containers for cpu/disk usage

Install
-------
```
wget --no-check-certificate https://raw.githubusercontent.com/FastVPSEestiOu/open_vestat/master/open_vestat.pl -O /usr/local/sbin/open_vestat
wget --no-check-certificate https://raw.githubusercontent.com/FastVPSEestiOu/open_vestat/master/open_vestat_bash_completion -O /etc/bash_completion.d/open_vestat
```

Usage
--------
```
open_vestat [ --sort-by ( cpu | disk_time | disk_sectors ) ] [ --help ]
```

Options
-------

- --help

Print help message

- --sort-by

Sorting output for cpu or disk\_time or disk\_sectors (by cpu as default)

Desctiption
-----------

We use cgroups for count use cpu/blkio.time/blkio.sectors

open_vestat_bash_completion - bash completion for vestat

Contributors
-----------
- [Pavel Odintsov](https://github.com/pavel-odintsov)
- [Sergei Mamonov](https://github.com/mrqwer88)
