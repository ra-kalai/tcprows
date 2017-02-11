TCPROWS, TCP Relay Over WebSocket
=================================


About
------

tcprows, is a command line tool, to relay a listening TCP socket to another device, through WebSocket.


Why would I want to encapsulate a TCP connection, over a WebSocket ?

  - Make a Web Client for an existing application / protocol.
  - Evade moronic enterprise / unsafe network, configured to disallow you from making any SSH connection.


Usage Example
--------------

On an remotely accessible machine under your control *A*:

    # forward ssh port to websocket
    ./tcprows -s 'http://0.0.0.0:8080/work-harder' localhost:22

On another machine *B* on your jail network:

    # export http_proxy=10.8.8.8:8080 
    # export https_proxy=10.8.8.8:8080
    
    ./tcprows -c 'http://remote_ip_or_domain:8080/work-harder' localhost:2222
    
you should by now be able to access to your *A* machine from *B* by typing
    
    ssh -p 2222 user@localhost

Performance
------------

should be able to easily saturate a 100Mbps line on common hardware..

Requirements
-------------

  * LEM with Lua 5.3
  * lem-websocket
  * lem-mbedtls

To Try
-------
    make # should produce an tcprows binary
    ./tcprows ...


License
-------

tcprows is distributed under the terms of a Three clause BSD license or under the [GNU Lesser General Public License][lgpl] any revision at your convenience.
[lgpl]: http://www.gnu.org/licenses/lgpl.html

Contact
-------

Please send bug reports, patches and feature requests to me ra@apathie.net.
