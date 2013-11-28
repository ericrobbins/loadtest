loadtest
========

Load test web sites with a simple bash script. You'll need gcc too. Includes a wget patch to enable overriding DNS for host lookups, nice for testing new builds.

The Wget patch allows you to override DNS lookups for specific host(s) without messing with /etc/hosts. I find this useful when I want to compare the output of a test server with the output of production servers with a simple command line change
