#! /bin/sh
sysctl -a |egrep -E "cpu\.[0-9]+\.temp"

