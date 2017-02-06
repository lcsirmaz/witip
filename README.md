### witip - a web based Information Theoretic Inequality Prover

This is a port of [minitip](https://github.com/lcsirmaz/minitip) as a web 
based utility. The server-side routines are written in [perl](https://www.perl.org)
with the exception of the LP solver engine which is  C frontend to glpk,
the [Gnu Linear Programming Kit](https:///www.gnu.org/software/glpk).

#### Requirements

Once the server is up and running, you can use wITIP with any decent
browser.

On the server-side: 
* an [Apache webserver](https://httpd.apache.org/) with mod_perl configured in;
* the glpk header files and runtime library;
* perl interpreter and a C complier

#### Server-side installation

Unpack wITIP and run the program

    PROMPT> perl bin/install.pl

It asks questions, and configures all necessary files; creates and include
file to be included in the Apache configuration. If everything goes
smoothly, edit the Apache configuration, and restart Apache. wITIP should
be up and running.

#### Content

* [bin](bin) for install.pl and the perl startup file
* [config](config) the generated apache include file is here
* [html](html) static html files: starting page, images, style sheets and
javascript
* [w](w) dynamic html files
* [perl_lib](perl_lib) perl library
* [prog](prog) the C frontend to the LP solver
* [template](template) template files to the install script


