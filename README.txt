---------------------------
CodeFlow Application Server
---------------------------

CodeFlow is an application server that uses Perl as the driving force behind it.
It is a webserver that is written in Perl, and has database connectivity built into it 
allowing your applications to utilze a database connection, using authenticated RPC 
requests to codeflow, and retreive results.  Having said that, while writing applications 
for CAS, you are able to utiliza a multitude of techniques in order to achive the
required results.

- Multi-application server.  That means that you can install a number of applications under 
  CAS, and utilize shared resources if required.
- Session management, CAS will take care of all session management for you.  No, that does 
  not mean authentication, that means that all requests to the CAS server are tracked 
  using a session cookie.
- Highly configurable.  You can view your current configuration in /etc/codeflow.conf 
  [relative path], and customize as required.
- CAS is modular, that means that specially written Perl modules can be written for 
  CAS that extend it's functionality.
- The use of Template Toolkit allows CAS to be very versatile, and a very rapid 
  application development enviroment.

The Core CodeFlow Development Team.
Omar
