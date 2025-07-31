# TLS Validation policy

This policy can validate TLS Client Certificate against a whitelist and Certificate Revocation List (CRL)

* Whitelist expects PEM formatted CA or Client certificates.
* Revocation List expects PEM formatted certificates.

It is not necessary to have the full certificate chain, just partial matches are allowed. For example you can add to the whitelist just leaf client certificates without the whole bundle with a CA certificate. However, you can change this behaviour with `allow_partial_chain`

## Configuration

For this policy to work, APIcast need to be setup to listen for TLS connection.

By default, during the TLS handshake, APIcast requests client certificates, but will not verify the certificate or terminate the request unless a TLS Validation Policy is in the chain. In most cases, the client not presenting a client certificate will not affect a service that does not have TLS Validation policy configured. The only exception is when a browser or front-end application uses the service. In this case, the browser will always prompt the user to choose a client certificate to send if they have any client certificates set up while accessing the service.

To work around this, set the environment variable `APICAST_HTTPS_VERIFY_CLIENT` to `off`. This instructs APIcast to request a client certificate only when the policy is in the chain.

NOTE: This policy is not compatible with `APICAST_PATH_ROUTING` or `APICAST_PATH_ROUTING_ONLY` when `APICAST_HTTPS_VERIFY_CLIENT` is set to `off`.

## Example

* Allow certificate verification with only an intermediate certificate.
```
{
  "name": "apicast.policy.tls_validation",
  "configuration": {
    "whitelist": [
      { "pem_certificate": ""-----BEGIN CERTIFICATE----- XXXXXX -----END CERTIFICATE-----"}
    ]
  }
}
```

* Use full certificate chain to verify client certificate
```
{
  "name": "apicast.policy.tls_validation",
  "configuration": {
    "whitelist": [
      { "pem_certificate": ""-----BEGIN CERTIFICATE----- XXXXXX -----END CERTIFICATE-----"}
    ],
    "allow_partial_chain": false
  }
}
```

With Certificate Revocation List (CRL)

```
{
  "name": "apicast.policy.tls_validation",
  "configuration": {
    "whitelist": [
      { "pem_certificate": ""-----BEGIN CERTIFICATE----- XXXXXX -----END CERTIFICATE-----"}
    ],
    "revocation_check_type": "crl",
    "revoke_list": [
      { "pem_certificate": ""-----BEGIN X509 CRL ----- XXXXXX -----END X509 CRL-----"}
    ]
  }
}
```

Checking certificate status with Online Certificate Status Protocol (OCSP). The responder url is
extracted from the certificate.

NOTE: When validating a client certificate with OCSP, APIcast requires the client to send the certificate chain
(i.e. if the certificate is signed with an intermediate certificate, the client needs to send both the client certificate + the intermediate certificate)

```
{
  "name": "apicast.policy.tls_validation",
  "configuration": {
    "whitelist": [
      { "pem_certificate": ""-----BEGIN CERTIFICATE----- XXXXXX -----END CERTIFICATE-----"}
    ],
    "revocation_check_type": "ocsp",
  }
}
```

Overwrite OCSP responder URL

```
{
  "name": "apicast.policy.tls_validation",
  "configuration": {
    "whitelist": [
      { "pem_certificate": ""-----BEGIN CERTIFICATE----- XXXXXX -----END CERTIFICATE-----"}
    ],
    "revocation_check_type": "ocsp",
    "ocsp_responder_url": "http://<ocsp-server>:<port>"
  }
}
```
