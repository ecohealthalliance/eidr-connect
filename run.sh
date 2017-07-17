#!/bin/bash
if [ ! -d "/itisSqlite" ]; then
    unzip -n itisSqlite.zip
    mv itisSqlite* itisSqlite
fi
supervisord --nodaemon --config /etc/supervisor/supervisord.conf
