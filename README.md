loadtest
========

Load test web sites with a simple bash script. You'll need gcc too. Includes a wget patch to enable overriding DNS for host lookups, nice for testing new builds.

There is a C source file embedded in the script that gets built, so ideally you need gcc. 
If there is no gcc, you need python, but the accuracy is less because python takes longer to execute:

# time python -c "import time; print int(time.time() * 1000);"
1385621597509
real	0m0.035s

# time ./now
1385621600937
real	0m0.004s


The Wget patch allows you to override DNS lookups for specific host(s) without messing with /etc/hosts. I find this useful when I want to compare the output of a test server with the output of production servers with a simple command line change.

For example, if www.myco.com is actually at public IP 4.2.2.2, and you build a test server 1t 192.168.1.33, you can do:

HOSTOVERRIDE=www.myco.com=192.168.1.33 wget http://www.myco.com/

to hit the test box, and wget with no HOSTOVERRIDE to hit the real server.
