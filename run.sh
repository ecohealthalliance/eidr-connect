#!/bin/bash
if [ ! -d "/itisSqlite" ]; then
    unzip itisSqlite.zip -d unzipped
    mv unzipped/itisSqlite* itisSqlite
    rmdir unzipped
fi
/bin/bash /eidr-connect.sh
