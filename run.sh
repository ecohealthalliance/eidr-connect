#!/bin/bash
unzip itisSqlite.zip
mv itisSqlite* itisSqlite
/var/run/supervisor.sock;
supervisord --nodaemon --config /etc/supervisor/supervisord.conf
