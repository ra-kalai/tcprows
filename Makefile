tcprows:
	git submodule init 
	git submodule update 
	( cd extra/lem/ ; ./configure --with-lua=builtin ; make)    && \
	( cd extra/lem-websocket/ ; make LUA_CFLAGS="-I../lem/lua" ) && \
	( cd extra/lem-mbedtls/ ; make LUA_INCDIR="../lem/lua" )	&& \
	( cd extra/lem/ ; make bin/lem-s V=s LEM_EXTRA_PACK=../../tcprows.lempack.lua:../lem-mbedtls/lempack.lua:../lem-websocket/lempack.lua )
	mv extra/lem/bin/lem-s tcprows

clean:
	rm -f tcprows
	( cd extra/lem/ ; make clean)
	( cd extra/lem-websocket/ ; make clean)
	( cd extra/lem-mbedtls/ ; make clean)
