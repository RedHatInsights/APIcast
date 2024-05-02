clean:
	- rm *.crt *.key *.pem *.csr

ca:
	openssl genrsa -out rootCA.key 2048
	openssl req -batch -new -x509 -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem

clientcerts:
	openssl req -subj '/CN=$(DOMAIN)'  -newkey rsa:4096 -nodes \
			-sha256 \
			-days 3650 \
			-keyout $(DOMAIN).key \
			-out $(DOMAIN).csr
	chmod +r $(DOMAIN).key
	openssl x509 -req -in $(DOMAIN).csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out $(DOMAIN).crt -days 500 -sha256
	cat $(DOMAIN).key $(DOMAIN).crt >$(DOMAIN).pem
