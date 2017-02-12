tcprows:
	git submodule init 
	git submodule update 
	( cd extra/lem/ ; ./configure --with-lua=builtin ; make)    && \
	( cd extra/lem-mbedtls/ ; LEM_INCDIR="-I../lem/lua -I../lem/libev -I../lem/include" make )	&& \
	( cd extra/lem/ ; make bin/lem-s V=s LEM_EXTRA_PACK=../../tcprows.lempack.lua:../lem-mbedtls/lempack.lua:../lem-websocket/lempack.lua )
	mv extra/lem/bin/lem-s tcprows

clean:
	rm -f tcprows
	( cd extra/lem/ ; make clean)
	( cd extra/lem-websocket/ ; make clean)
	( cd extra/lem-mbedtls/ ; make clean)
