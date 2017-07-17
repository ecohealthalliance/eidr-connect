#!/bin/bash
if [ ! -d "/itisSqlite" ]; then
    unzip itisSqlite.zip -d unzipped
    mv unzipped/itisSqlite* itisSqlite
    rmdir unzipped
fi
supervisord --nodaemon --config /etc/supervisor/supervisord.conf
